ARG IMAGE_EXT

ARG REGISTRY=ghcr.io/epics-containers
# Built on the plain epics-base developer image (7.0.10ec2): the template's
# iocStats, pvlogging and autosave, plus asyn and delaygen from ibek-support
# pinned at 8545fa2 (the commit ioc-motion builds with). No vendor code.
ARG RUNTIME=${REGISTRY}/epics-base${IMAGE_EXT}-runtime:7.0.10ec2
ARG DEVELOPER=${REGISTRY}/epics-base${IMAGE_EXT}-developer:7.0.10ec2

##### build stage ##############################################################
FROM  ${DEVELOPER} AS developer

# The devcontainer mounts the project root to /epics/generic-source
# Using the same location here makes devcontainer/runtime differences transparent.
ENV SOURCE_FOLDER=/epics/generic-source
# connect ioc source folder to its know location
RUN ln -s ${SOURCE_FOLDER}/ioc ${IOC}

# get the current versions of pvi and ibek
COPY requirements.txt requirements.txt
RUN uv pip install --upgrade -r requirements.txt

WORKDIR ${SOURCE_FOLDER}/ibek-support

COPY ibek-support/_ansible _ansible
ENV PATH=$PATH:${SOURCE_FOLDER}/ibek-support/_ansible

COPY ibek-support/iocStats/ iocStats
RUN ansible.sh iocStats

COPY ibek-support/pvlogging/ pvlogging/
RUN ansible.sh pvlogging

COPY ibek-support/autosave/ autosave
RUN ansible.sh autosave

COPY ibek-support/asyn/ asyn
RUN ansible.sh asyn

# epics-modules/delaygen a2e58d7 (drvAsynDG645 for the SRS DG645) with the
# init-clear-status patch (README "DG645"). Upstream ibek-support has no
# recipe for it, so this copy is the only one and ansible finds the module once.
COPY ibek-support-geecs/delaygen/ ${SOURCE_FOLDER}/ibek-support-geecs/delaygen/
RUN ansible.sh delaygen

# get the ioc source and build it
COPY ioc ${SOURCE_FOLDER}/ioc
RUN ansible.sh ioc

# generate a manifest of installed EPICS modules and python packages
# IOC_VERSION is declared here, not earlier: every RUN after an ARG sees it,
# so a new value (each branch or tag) would rebuild all the steps above
ARG IOC_VERSION=unknown
COPY scripts/generate_manifest.py /tmp/generate_manifest.py
RUN python3 /tmp/generate_manifest.py "${IOC_VERSION}"

##### runtime preparation stage ################################################
FROM developer AS runtime_prep

# get the products from the build stage and reduce to runtime assets only
# /python is created by uv and is needed in the runtime target
# /epics/versions.json is the manifest of support module and python versions
RUN ibek ioc extract-runtime-assets /assets /python /epics/versions.json

##### runtime stage ############################################################
FROM ${RUNTIME} AS runtime

# get runtime assets from the preparation stage
COPY --from=runtime_prep /assets /

# install runtime system dependencies, collected from install.sh scripts
RUN ibek support apt-install-runtime-packages

# launch the startup script with stdio-expose to allow console connections
CMD ["bash", "-c", "${IOC}/start.sh"]
