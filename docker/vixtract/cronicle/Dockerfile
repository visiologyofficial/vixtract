FROM node:22.10.0-alpine3.19

# Python install
RUN apk add --no-cache python3=3.11.10-r0  py3-pip=23.3.1-r0 \
        gcc=13.2.1_git20231014-r0 python3-dev=3.11.10-r0 \
        musl-dev=1.2.4_git20230717-r4 linux-headers=6.5-r0 cmake=3.27.8-r0 \
        build-base=0.5-r3 py3-pyarrow=14.0.1-r3 curl=8.9.1-r1

# Add essential libs
COPY requirements.txt /requirements.txt

RUN pip3 install --break-system-packages -r /requirements.txt

# Install Chronicle
SHELL ["/bin/ash", "-eo", "pipefail", "-c"]
RUN curl -S https://raw.githubusercontent.com/jhuckaby/Cronicle/master/bin/install.js | node

WORKDIR /opt/cronicle/bin

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3012

ENTRYPOINT ["/entrypoint.sh"]
