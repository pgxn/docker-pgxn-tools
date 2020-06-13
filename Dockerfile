FROM debian:buster-slim AS pgxn-config
#FROM ruby:buster-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential pgxnclient ca-certificates gnupg \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/*
#    && gem install pgxn_utils

COPY bin/run-pg-test /usr/local/bin/

ADD  https://www.postgresql.org/media/keys/ACCC4CF8.asc .
RUN apt-key add ACCC4CF8.asc \
    && rm ACCC4CF8.asc \
    && echo deb http://apt.postgresql.org/pub/repos/apt buster-pgdg main > /etc/apt/sources.list.d/pgdg.list
