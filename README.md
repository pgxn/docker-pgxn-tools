PGXN Extension Build and Test Tools Docker Image
================================================

``` sh
docker run -it --rm --mount "type=bind,src=$(pwd),dst=/repo" pgxn/pgxn-tools \
    sh -c 'cd /repo && pg-start 12 && pg-build-test'
```

This project provides a simple Docker image to enable the automated testing
of PGXN extensions against multiple versions of PostgreSQL. The image
contains these utilities:

*   [`pgxn`]: The PGXN command-line client
*   [`pg-start`] Pass a PostgreSQL major version to install and starts a PostgreSQL cluster
*   [`pg-build-test`]: Builds and tests an extension in the current directory

The image is based on the Debian Buster Slim image, and uses the
[PostgreSQL Apt] repository to install PostgreSQL, supporting versions
[back to 8.4].

GitHub Workflow
---------------

Here's a sample [GithHub Workflow]:

``` yaml
name: CI
on: [push]
jobs:
  build:
    strategy:
      matrix:
        pg: [12, 11, 10, 9.6, 9.5, 9.4, 9.3, 9.2]
    name: 🐘 PostgreSQL ${{ matrix.pg }}
    runs-on: ubuntu-latest
    container:
      image: pgxn/pgxn-tools
    steps:
      - run: pg-start ${{ matrix.pg }}
      - uses: actions/checkout@v2
      - run: pg-build-test
```

Tools
-----

Some details on the tools:

### [`pg-start`]

``` sh
pg-start 12
pg-start 11 libsodium-dev
```
Installs the specified version of PostgreSQL from the [PostgreSQL Apt] community
repository, as well as any additional Debian core or PostgreSQL packages passed
as subsequent arguments. It then starts the cluster on port 5432 with the system
locale ane encoding (`C.UTF-8` by default) and trust authentication enabled. If
you need the cluster configured with a specific locale (for collation
predictability, for example), set the `$LANG` environment variable before
calling `pg-start`.

### [`pg-build-test`]

``` sh
pg-build-test
```

Simply builds, installs, and tests a PostgreSQL extension or other code in the
current directory. Effectively the equivalent of:

``` sh
make
make install
make installcheck
```

But a bit more, to ensure that the tests run as the `postgres` user, and if
tests fail to emit the contents of the `regression.diffs` file. Designed to
cover the most common PostgreSQL extension continuous integration needs.

### [`pgxn`]

``` sh
pgxn install hostname
```

The PGXN Client enables the installation of additional dependencies, should you
need them, from PGXN. You'd generally want to use it to install dependencies
before building and running tests.

[`pgxn`]: https://github.com/pgxn/pgxnclient
[`pg-start`]: bin/pg-start
[`pg-build-test`]: bin/pg-build-test
[PostgreSQL Apt]: https://wiki.postgresql.org/wiki/Apt
[back to 8.4]: http://apt.postgresql.org/pub/repos/apt/dists/buster-pgdg/
[GithHub Workflow]: https://help.github.com/en/actions/configuring-and-managing-workflows
