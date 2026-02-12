FROM kong:latest

USER root

# install curl + build deps
RUN apt-get update && \
    apt-get install -y curl git build-essential libssl-dev && \
    luarocks install lua-resty-openssl

# Copy custom plugins
RUN mkdir -p /usr/local/kong/plugins/kong/plugins
COPY plugins/response-aes-encrypt /usr/local/kong/plugins/kong/plugins/response-aes-encrypt

# Fix ownership
RUN chown -R kong:kong /usr/local/kong/plugins

USER kong
