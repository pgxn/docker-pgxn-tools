PGXN Extension Build and Test Tools Docker Image
================================================

[![Test & Release Status](https://github.com/pgxn/docker-pgxn-tools/workflows/CI/CD/badge.svg)](https://github.com/pgxn/docker-pgxn-tools/actions)

``` sh
docker run -it --rm --mount "type=bind,src=$(pwd),dst=/repo" pgxn/pgxn-tools \
    sh -c 'cd /repo && pg-start 12 && pg-build-test'
```

This project provides a simple Docker image to enable the automated testing
of PGXN extensions against multiple versions of PostgreSQL. The image
contains these utilities:

*   [`pgxn`][cli]: The PGXN command-line client
*   [`pg-start`] Pass a PostgreSQL major version to install and starts a PostgreSQL cluster
*   [`pg-build-test`]: Builds and tests an extension in the current directory
*   [`pgxn-bundle`]: Validates the PGXN META.json file and bundles up a release
*   [`pgxn-release`]: Release to PGXN

The image is based on the Debian Buster Slim image, and uses the
[PostgreSQL Apt] repository to install PostgreSQL, supporting versions
[back to 8.4].

GitHub Workflow
---------------

Here's a sample [GithHub Workflow]:

``` yaml
name: CI
  push:
    branches: ['*']
  pull_request:
    branches: ['*']
jobs:
  build:
    strategy:
      matrix:
        pg: [13, 12, 11, 10, 9.6, 9.5, 9.4, 9.3, 9.2, 9.1, 9.0, 8.4]
    name: 🐘 PostgreSQL ${{ matrix.pg }}
    runs-on: ubuntu-latest
    container: pgxn/pgxn-tools
    steps:
      - name: Start PostgreSQL ${{ matrix.pg }}
        run: pg-start ${{ matrix.pg }}
      - name: Check out the repo
        uses: actions/checkout@v2
      - name: Test on PostgreSQL ${{ matrix.pg }}
        run: pg-build-test
  release:
    name: Release on PGXN
    # Release upon push to main when the test job succeeds.
    needs: test
    if: github.ref == 'refs/heads/main' && github.event_name == 'push' && needs.test.result == 'success'
    runs-on: ubuntu-latest
    container:
      image: pgxn/pgxn-tools
      env:
        PGXN_USERNAME: ${{ secrets.PGXN_USERNAME }}
        PGXN_PASSWORD: ${{ secrets.PGXN_PASSWORD }}
    steps:
      - name: Check out the repo
        uses: actions/checkout@v2
      - name: Bundle the Release
        run: pgxn-bundle
      - name: Release on PGXN
        run: pgxn-release
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
locale and encoding (`C.UTF-8` by default) and trust authentication enabled. If
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
cover the most common PostgreSQL extension build-and-test patterns.

### [`pgxn-bundle`]

``` sh
pgxn-bundle
PGXN_DIST_NAME=widget PGXN_DIST_VERSION=1.0.0 pgxn-bundle
```

Validates the PGXN `META.json` file and bundles up the repository for release
to PGXN. It does so by archiving the Git repository like so:

``` sh
git archive --format zip --prefix=${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}/ \
            --output ${PGXN_DIST_NAME}-${PGXN_DIST_VERSION} HEAD
```

If the `$PGXN_DIST_NAME` or `$PGXN_DIST_VERSION` variable is not set, the extension
name and version are read from the `META.json` file (indeed, this is preferred).
The zip file will be at the root of the repository, ready for release.

### [`pgxn-release`]

``` sh
export PGXN_USERNAME=susan
export PGXN_PASSWORD='s00per&ecret'
pgxn-release
pgxn-release widget-1.0.0.zip
```

Uploads a release zip file to PGXN. The `$PGXN_USERNAME` and `$PGXN_PASSWORD`
variables must be set. If no release file is passed, it will use the
`$PGXN_DIST_NAME` or `$PGXN_DIST_VERSION` variables or read the `META.json`
file, just like `pgxn-bundle` does. This assumes that you've properly updated
your `META.json` file and any other files that need a version increment or
timestamp to mark release. This might be most useful in a "release" CI/CD
event, or for a main branch reserved for released code.

### [`pgxn`][cli]

``` sh
pgxn install hostname
```

The [PGXN client][cli] provides an interface to extensions distributed on
[PGXN]. Use it to install of additional dependencies, should you need them, from
[PGXN]. You'd generally want to use it to install dependencies before building and
running tests, for example:

``` sh
pg-start 12
pgxn install semver
pg-build-test
```

Please refer to [the docs] for all the details.

Author
------

[David E. Wheeler]

Copyright and License
---------------------

Copyright (c) 2020 The PGXN Maintainers. Distributed under the [PostgreSQL License]
(see [LICENSE]).

  [cli]: https://github.com/pgxn/pgxnclient
  [`pg-start`]: bin/pg-start
  [`pg-build-test`]: bin/pg-build-test
  [`pgxn-bundle`]: bin/pgxn-bundle
  [`pgxn-release`]: bin/pgxn-release
  [PostgreSQL Apt]: https://wiki.postgresql.org/wiki/Apt
  [back to 8.4]: http://apt.postgresql.org/pub/repos/apt/dists/buster-pgdg/
  [GithHub Workflow]: https://help.github.com/en/actions/configuring-and-managing-workflows
  [PGXN]: https;//pgxn.org/ "The PostgreSQL Extension Network"
  [David E. Wheeler]: https://justatheory.com/
  [PostgreSQL License]: https://opensource.org/licenses/PostgreSQL
  [LICENSE]: LICENSE
  [the docs]: https://pgxn.github.io/pgxnclient/