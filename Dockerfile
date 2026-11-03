# CareBridge AI image, built locally on top of the InterSystems AI Hub Early Access image.
# The base image is not on a public registry: load it from the EAP portal first (see README).
# Never push this image, or any image built from it, to a public registry.
ARG IRIS_IMAGE=irishealth-community:2027.1.0AI.109.0
FROM ${IRIS_IMAGE}

USER root
RUN mkdir -p /home/irisowner/dev /home/irisowner/carebridge && chown -R irisowner:irisowner /home/irisowner/dev /home/irisowner/carebridge
USER irisowner

WORKDIR /home/irisowner/dev
COPY --chown=irisowner:irisowner module.xml merge.cpf iris.script ./
COPY --chown=irisowner:irisowner src ./src
COPY --chown=irisowner:irisowner web ./web

# iris.script (terminal commands, no comments allowed):
#  1. maps IPM, which IRIS for Health AI Hub images ship in HSLIB, into every namespace;
#  2. un-expires default passwords (development container only; do not do this in production);
#  3. installs CareBridge with "zpm load", exactly as an IPM user would: compile, web apps, seed data,
#     Workflow role, web security role, production autostart. A failed install fails the build.
RUN iris start IRIS \
 && iris merge IRIS /home/irisowner/dev/merge.cpf \
 && iris session IRIS < /home/irisowner/dev/iris.script \
 && iris stop IRIS quietly
