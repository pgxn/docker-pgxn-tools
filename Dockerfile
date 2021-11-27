FROM debian:bullseye-slim AS pgxn-config

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential clang llvm llvm-dev llvm-runtime \
        pgxnclient libtap-parser-sourcehandler-pgtap-perl sudo gosu \
        ca-certificates gnupg2 zip curl git libicu-dev libxml2 locales ssl-cert \
    && apt-get -y purge postgresql-client-common \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/* \
    && curl -L https://cpanmin.us/ -o cpanm && chmod +x cpanm \
    && ./cpanm --notest PGXN::Meta::Validator \
    && rm -r cpanm ~/.cpanm \
    && echo Defaults	lecture = never >> /etc/sudoers \
    && perl -i -pe 's/\bALL$/NOPASSWD:ALL/g' /etc/sudoers \
    && echo 'postgres	ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers

COPY bin/* /usr/local/bin/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
