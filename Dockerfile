FROM debian:bookworm-slim AS pgxn-config

ADD https://salsa.debian.org/postgresql/postgresql-common/-/raw/master/pgdg/apt.postgresql.org.sh /usr/local/bin/

RUN chmod +x /usr/local/bin/apt.postgresql.org.sh \
    # Install apt dependencies
    && apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential clang llvm llvm-dev llvm-runtime cmake libtoml-parser-perl \
        pgxnclient libtap-parser-sourcehandler-pgtap-perl libipc-run-perl libtest-simple-perl sudo gosu \
        ca-certificates gnupg2 zip unzip libarchive-tools curl git libicu-dev libxml2 locales ssl-cert \
    # Clean out unwanted stuff
    && apt-get -y purge postgresql-client-common \
    && apt-get clean \
    && rm -rf /var/cache/apt/* /var/lib/apt/lists/* \
    # Install CPAN dependencies
    && curl -L https://cpanmin.us/ -o cpanm && chmod +x cpanm \
    && ./cpanm --notest PGXN::Meta::Validator \
    && rm -r cpanm ~/.cpanm \
    # Configure sudoers to allow otherwise unprivileged users to do everything.
    && echo Defaults	lecture = never >> /etc/sudoers \
    && echo 'Defaults env_keep += "CARGO_* RUSTUP_* PGRX_*"' >> /etc/sudoers \
    && perl -i -pe 's/\bALL$/NOPASSWD:ALL/g' /etc/sudoers \
    && echo 'postgres	ALL=(ALL:ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && perl -i -pe 's/^(Defaults\s+secure_path)/# $1/' /etc/sudoers \
    # Ensure Git can do stuff in the working directory (issue #5).
    && git config --system --add safe.directory '*' \
    # Install git-archive-all
    && curl -O https://raw.githubusercontent.com/Kentzo/git-archive-all/1.23.1/git_archive_all.py \
    && perl -i -pe 's/python/python3/' git_archive_all.py \
    && install -m 0755 git_archive_all.py "$(git --exec-path)/git-archive-all" \
    && rm git_archive_all.py \
    # Install the Rust toolchain
    && curl --proto '=https' --tlsv1.2 https://sh.rustup.rs -sSf | env CARGO_HOME=/usr/share/cargo RUSTUP_HOME=/usr/share/rustup bash -s -- -y --profile minimal --component rustfmt --component clippy \
    && chmod 0777 /usr/share/cargo /usr/share/cargo/bin

COPY bin/* /usr/local/bin/

ENV LC_ALL=C.UTF-8 LANG=C.UTF-8 CARGO_HOME=/usr/share/cargo PGRX_HOME=/tmp/.pgrx RUSTUP_HOME=/usr/share/rustup PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/share/cargo/bin
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
