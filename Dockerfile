FROM debian:bookworm-slim AS pgxn-config

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential clang llvm llvm-dev llvm-runtime cmake \
        pgxnclient libtap-parser-sourcehandler-pgtap-perl libipc-run-perl libtest-simple-perl sudo gosu \
        ca-certificates gnupg2 zip unzip libarchive-tools curl git libicu-dev libxml2 locales ssl-cert \
    && apt-get -y purge postgresql-client-common \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/* \
    && curl -L https://cpanmin.us/ -o cpanm && chmod +x cpanm \
    && ./cpanm --notest PGXN::Meta::Validator \
    && rm -r cpanm ~/.cpanm \
    && echo Defaults	lecture = never >> /etc/sudoers \
    && perl -i -pe 's/\bALL$/NOPASSWD:ALL/g' /etc/sudoers \
    && echo 'postgres	ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers \
    # Ensure Git can do stuff in the working directory (issue #5).
    && git config --system --add safe.directory '*' \
    # Install git-archive-all
    && curl -O https://raw.githubusercontent.com/Kentzo/git-archive-all/1.23.1/git_archive_all.py \
    && perl -i -pe 's/python/python3/' git_archive_all.py \
    && install -m 0755 git_archive_all.py "$(git --exec-path)/git-archive-all" \
    && rm git_archive_all.py

COPY bin/* /usr/local/bin/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
