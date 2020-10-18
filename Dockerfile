FROM debian:buster-slim AS pgxn-config

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh \
    && apt-get update \
    && apt-get install -y --no-install-recommends build-essential pgxnclient ca-certificates gnupg2 zip curl git libicu-dev clang llvm llvm-dev llvm-runtime libxml2 locales ssl-cert \
    && apt-get -y purge postgresql-client-common \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/* \
    && curl -L https://cpanmin.us/ -o cpanm && chmod +x cpanm \
    && ./cpanm --notest PGXN::Meta::Validator \
    && rm -r cpanm ~/.cpanm

COPY bin/* /usr/local/bin/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8
