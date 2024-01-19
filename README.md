PGXN Extension Build and Test Tools Docker Image
================================================

[![Test & Release Status](https://github.com/pgxn/docker-pgxn-tools/workflows/CI/CD/badge.svg)](https://github.com/pgxn/docker-pgxn-tools/actions)

``` sh
docker run -it --rm -w /repo --volume "$PWD:/repo" pgxn/pgxn-tools \
    sh -c 'pg-start 12 && pg-build-test'
```

This project provides a simple Docker image to enable the automated testing of
PGXN extensions against multiple versions of PostgreSQL, as well as publishing
releases to PGXN. The image contains these utilities:

*   [`pgxn`][cli]: The PGXN command-line client
*   [`pg_prove`]: Runs and harnessing pgTAP tests
*   [`pg-start`] Pass a PostgreSQL major version to install and starts a PostgreSQL cluster
*   [`pg-build-test`]: Builds and tests an extension in the current directory
*   [`pgxn-bundle`]: Validates the PGXN META.json file and bundles up a release
*   [`pgxn-release`]: Release to PGXN

The image is based on the Debian Bookworm Slim image, and uses the
[PostgreSQL Apt] repository to install PostgreSQL, supporting versions
[back to 8.2], as well as the latest prerelease version.

Unprivileged User
-----------------

By default the container runs as `root`. To run as an unprivileged user, pass
the `AS_USER` environment variable, and a user with that name will be created
with `sudo` privileges (already used by `pg-start` and `pg-build-test`):

``` sh
docker run -it --rm -w /repo -e AS_USER=worker \
    --volume "$PWD:/repo" pgxn/pgxn-tools \
    sh -c 'sudo pg-start 14 && pg-build-test'
```

The created user will have the UID 1001 unless `LOCAL_UID` is passed, which can
usefully be set to the local UID so that the user has permission to access files
in a volume:

``` sh
docker run -it --rm -w /repo -e AS_USER=worker -e LOCAL_UID=$(id -u) \
    --volume "$PWD:/repo" pgxn/pgxn-tools \
    sh -c 'sudo pg-start 14 && pg-build-test'
```

If no `LOCAL_UID` is set but `GITHUB_EVENT_PATH` is set (as it is in GitHub
workflows), the UID will be set to the same value as the owner of the
`GITHUB_EVENT_PATH` file. This allows the user to have full access to the
GitHub project volume.

### Postgres User

The `postgres` user, created by `pg-start`, also has full permission to use
`sudo` without a password prompt.

GitHub Workflow
---------------

Here's a sample [GitHub Workflow] to run tests on multiple versions of
PostgreSQL for every push and pull request:

``` yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        pg: [16, 15, 14, 13, 12, 11, 10, 9.6, 9.5, 9.4, 9.3, 9.2, 9.1, 9.0, 8.4, 8.3, 8.2]
    name: 🐘 PostgreSQL ${{ matrix.pg }}
    runs-on: ubuntu-latest
    container: pgxn/pgxn-tools
    steps:
      - name: Start PostgreSQL ${{ matrix.pg }}
        run: pg-start ${{ matrix.pg }}
      - name: Check out the repo
        uses: actions/checkout@v3
      - name: Test on PostgreSQL ${{ matrix.pg }}
        run: pg-build-test
```

If you need to run the tests as an unprivileged user, pass the `AS_USER`
variable as a container option:

``` yaml
    container:
      image: pgxn/pgxn-tools
      options: -e AS_USER=randy
```

This example demonstrates automatic publishing of a release whenever a tag is
pushed matching `v*`. It publishes both to GitHub (using the [create-release]
and [upload-release-asset] actions) and to PGXN:

``` yaml
name: Release
on:
  push:
    tags:
      - 'v*' # Push events matching v1.0, v20.15.10, etc.
jobs:
  release:
    name: Release on GitHub and PGXN
    runs-on: ubuntu-latest
    container: pgxn/pgxn-tools
    env:
      # Required to create GitHub release and upload the bundle.
      GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
    steps:
    - name: Check out the repo
      uses: actions/checkout@v3
    - name: Bundle the Release
      id: bundle
      run: pgxn-bundle
    - name: Release on PGXN
      env:
        # Required to release on PGXN.
        PGXN_USERNAME: ${{ secrets.PGXN_USERNAME }}
        PGXN_PASSWORD: ${{ secrets.PGXN_PASSWORD }}
      run: pgxn-release
    - name: Create GitHub Release
      id: release
      uses: actions/create-release@v1
      with:
        tag_name: ${{ github.ref }}
        release_name: Release ${{ github.ref }}
        body: |
          Changes in this Release
          - First Change
          - Second Change
    - name: Upload Release Asset
      uses: actions/upload-release-asset@v1
      with:
        # Reference the upload URL and bundle name from previous steps.
        upload_url: ${{ steps.release.outputs.upload_url }}
        asset_path: ./${{ steps.bundle.outputs.bundle }}
        asset_name: ${{ steps.bundle.outputs.bundle }}
        asset_content_type: application/zip
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
as subsequent arguments. It then starts the cluster on 5432 (or `$PGPORT` if
it's set) with the system locale and encoding (`C.UTF-8` by default) and trust
authentication enabled. If you need the cluster configured with a specific
locale (for collation predictability, for example), set the `$LANG` environment
variable before calling `pg-start`.

If you need to access the `postgresql.conf`, say to add additional configuration,
you can use the `SHOW config_file` SQL command like so:

``` sh
psql --no-psqlrc -U postgres -Atqc 'SHOW config_file'
```

For example, to load PL/Perl:

``` sh
echo "shared_preload_libraries = '$libdir/plperl'" >> $(psql --no-psqlrc -U postgres -Atqc 'SHOW config_file')
```

The cluster is named "test", and if you need to restart it (e.g. because you
modified the `postgresql.conf` file), use `pg_ctlcluster` like so:

``` sh
pg_ctlcluster 12 test restart
```

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

If the `$PGXN_DIST_NAME` or `$PGXN_DIST_VERSION` variable is not set, the
extension name and version are read from the `META.json` file (indeed, this
is preferred). The zip file will be at the root of the repository, ready for
release, and the name of the bundle will be appended to the `$GITHUB_OUTPUT`
file in this format, for use in GitHub Actions such as [upload-release-asset]:

``` sh
echo bundle=${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}.zip >> $GITHUB_OUTPUT
```

To exclude files from the bundle, add a `.gitattributes` file to the repository
and use the `export-ignore` attribute to identify files and directories to
exclude. This example excludes some typical Git and GitHub files and
directories, as well as a test script:

```
.gitignore export-ignore
.gitattributes export-ignore
test.sh export-ignore
.github export-ignore
```

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

### [`pg_prove`]

``` sh
pg-start 12
pg_prove -r --ext .sql test/
```

[`pg_prove`] is a command-line application to run one or more [pgTAP] tests in a
PostgreSQL database.

[pgTAP] is a suite of database functions that make it easy to write
[TAP]-emitting unit tests in `psql` scripts or xUnit-style test functions. The
TAP output is suitable for harvesting, analysis, and reporting by [`pg_prove`]
or other [TAP] tools.

### Installed Packages

The image includes these packages; pass additional packages to
[`pg-start`](#pg-start) to install them while setting up PostgreSQL.

*   [build-essential](https://packages.debian.org/bookworm/build-essential)
*   [clang](https://packages.debian.org/bookworm/clang)
*   [llvm](https://packages.debian.org/bookworm/llvm)
*   [llvm-dev](https://packages.debian.org/bookworm/llvm-dev)
*   [llvm-runtime](https://packages.debian.org/bookworm/llvm-runtime)
*   [pgxnclient](https://packages.debian.org/bookworm/pgxnclient)
*   [libtap-parser-sourcehandler-pgtap-perl](https://packages.debian.org/bookworm/libtap-parser-sourcehandler-pgtap-perl)
*   [sudo](https://packages.debian.org/bookworm/sudo)
*   [gosu](https://packages.debian.org/bookworm/gosu)
*   [ca-certificates](https://packages.debian.org/bookworm/ca-certificates)
*   [gnupg2](https://packages.debian.org/bookworm/gnupg2)
*   [zip](https://packages.debian.org/bookworm/zip)
*   [unzip](https://packages.debian.org/bookworm/unzip)
*   [curl](https://packages.debian.org/bookworm/curl)
*   [git](https://packages.debian.org/bookworm/git)
*   [libicu-dev](https://packages.debian.org/bookworm/libicu-dev)
*   [libxml2](https://packages.debian.org/bookworm/libxml2)
*   [locales](https://packages.debian.org/bookworm/locales)
*   [ssl-cert](https://packages.debian.org/bookworm/ssl-cert)

Author
------

[David E. Wheeler]

Copyright and License
---------------------

Copyright (c) 2020-2024 The PGXN Maintainers. Distributed under the
[PostgreSQL License] (see [LICENSE]).

  [cli]: https://github.com/pgxn/pgxnclient
  [`pg_prove`]: https://metacpan.org/pod/pg_prove
  [`pg-start`]: bin/pg-start
  [`pg-build-test`]: bin/pg-build-test
  [`pgxn-bundle`]: bin/pgxn-bundle
  [`pgxn-release`]: bin/pgxn-release
  [PostgreSQL Apt]: https://wiki.postgresql.org/wiki/Apt
  [back to 8.2]: http://apt.postgresql.org/pub/repos/apt/dists/bookworm-pgdg/
  [GithHub Workflow]: https://help.github.com/en/actions/configuring-and-managing-workflows
  [create-release]: https://github.com/actions/create-release
  [upload-release-asset]: https://github.com/actions/upload-release-asset
  [PGXN]: https;//pgxn.org/ "The PostgreSQL Extension Network"
  [David E. Wheeler]: https://justatheory.com/
  [PostgreSQL License]: https://opensource.org/licenses/PostgreSQL
  [LICENSE]: LICENSE
  [the docs]: https://pgxn.github.io/pgxnclient/
  [pgTAP]: https://pgtap.org/
  [TAP]: https://testanything.org "Test Anything Protocol"
