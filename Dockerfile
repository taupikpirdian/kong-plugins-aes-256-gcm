FROM kong:latest

USER root

# install curl + build deps
RUN apt-get update && \
    apt-get install -y curl git build-essential libssl-dev && \
    luarocks install lua-resty-openssl

USER kong
