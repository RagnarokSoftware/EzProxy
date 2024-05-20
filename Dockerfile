FROM debian:bullseye

ARG DANTE_URL="https://www.inet.no/dante/files/dante-1.4.3.tar.gz"
ARG DANTE_SHA256="418a065fe1a4b8ace8fbf77c2da269a98f376e7115902e76cda7e741e4846a5d"
ARG DANTE_INTERFACES=""
ARG DANTE_DIR="/dante"

ENV DANTE_USER="user"
ENV DANTE_PASS="pass"
ENV DANTE_PORT="1080"
ENV DANTE_INTERFACES=""
ENV DANTE_WORKERS="10"

# build-essential curl openssl unzip
RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    automake \
    autoconf \
    openssl \
    unzip \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p $DANTE_DIR
WORKDIR $DANTE_DIR
RUN curl -fsSL -o dante.tar.gz $DANTE_URL
RUN echo "$DANTE_SHA256  dante.tar.gz" | sha256sum -c -
RUN tar -xzf dante.tar.gz --strip-components=1
RUN cp /usr/share/automake*/config.guess ./config.guess
RUN ./configure
RUN make install

COPY ./entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1080

ENTRYPOINT ["/entrypoint.sh"]