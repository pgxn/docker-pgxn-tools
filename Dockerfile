FROM debian:buster-slim AS pgxn-config
#FROM ruby:buster-slim

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh \
    && apt-get update \
    && apt-get install -y --no-install-recommends build-essential pgxnclient ca-certificates gnupg2 \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*
#    && gem install pgxn_utils

COPY bin/* /usr/local/bin/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8
