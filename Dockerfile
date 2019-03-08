FROM extremeshok/baseimage-alpine:latest AS BUILD

LABEL mantainer="Adrian Kriel <admin@extremeshok.com>" vendor="eXtremeSHOK.com"

RUN echo "**** install powerdns ****" \
  && apk-install pdns pdns-backend-sqlite3 sqlite

RUN echo "**** install bash runtime packages ****" \
  && apk-install \
    bash \
    coreutils \
    curl \
    openssl \
    tzdata

#RUN echo "**** Install envtpl ****" \
#  && pip3 install --no-cache-dir envtpl

# add local files
COPY ./rootfs/ /

RUN echo "**** configure ****" \
  && mkdir /data \
  && chown -Rv pdns:pdns /data \
  && chmod 777 /xshok_gen_conf.sh

VOLUME ["/data"]
WORKDIR /data

EXPOSE 53/tcp
EXPOSE 53/udp
EXPOSE 8083/tcp

ENTRYPOINT ["/init"]
