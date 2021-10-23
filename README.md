PGXN Extension Build and Test Tools Docker Image
================================================

[![Test & Release Status](https://github.com/pgxn/docker-pgxn-tools/workflows/CI/CD/badge.svg)](https://github.com/pgxn/docker-pgxn-tools/actions)

``` sh
docker run -it --rm --mount "type=bind,src=$(pwd),dst=/repo" pgxn/pgxn-tools \
    sh -c 'cd /repo && pg-start 12 && pg-build-test'
```

This project provides a simple Docker image to enable the automated testing of
PGXN extensions against multiple versions of PostgreSQL, as well as publishing
releases to PGXN. The image contains these utilities:

*   [`pgxn`][cli]: The PGXN command-line client
*   [`pg-start`] Pass a PostgreSQL major version to install and starts a PostgreSQL cluster
*   [`pg-build-test`]: Builds and tests an extension in the current directory
*   [`pgxn-bundle`]: Validates the PGXN META.json file and bundles up a release
*   [`pgxn-release`]: Release to PGXN

The image is based on the Debian Buster Slim image, and uses the
[PostgreSQL Apt] repository to install PostgreSQL, supporting versions
[back to 8.4], as well as the latest prerelease version.

GitHub Workflow
---------------

Here's a sample [GithHub Workflow] to run tests on multiple versions of
PostgreSQL for every push and pull request:

``` yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    strategy:
      matrix:
        pg: [15, 14, 13, 12, 11, 10, 9.6, 9.5, 9.4, 9.3, 9.2, 9.1, 9.0, 8.4]
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
```

This example demonstrates automatic publishing of a release whenever a tag is
pushed matching  `v*`. It publishes both to GitHub (using the [create-release]
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
      uses: actions/checkout@v2
    - name: Bundle the Release
      id: bundle
      run: pgxn-bundle
    - name: Release on PGXN
      env:
        # Required to release on PGXN.
        PGXN_USERNAME: ${{ secrets.PGXN_USERNAME }}
        PGXN_USERNAME: ${{ secrets.PGXN_PASSWORD }}
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
as subsequent arguments. It then starts the cluster on port 5432 with the system
locale and encoding (`C.UTF-8` by default) and trust authentication enabled. If
you need the cluster configured with a specific locale (for collation
predictability, for example), set the `$LANG` environment variable before
calling `pg-start`.

If you need to access the `postgresql.conf`, say to add additional configuration,
you can use the `SHOW config_file` SQL command like so:

``` sh
psql --no-psqlrc -U postgres -Atqc 'SHOW config_file'
```

For example, to load PL/Perl:

```
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
release, and the name of the bundle will be output in this format, for use in
GitHub Actions such as [upload-release-asset]:

``` sh
echo ::set-output name=bundle::${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}.zip
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

Author
------

[David E. Wheeler]

Copyright and License
---------------------

Copyright (c) 2020-2021 The PGXN Maintainers. Distributed under the
[PostgreSQL License] (see [LICENSE]).

  [cli]: https://github.com/pgxn/pgxnclient
  [`pg-start`]: bin/pg-start
  [`pg-build-test`]: bin/pg-build-test
  [`pgxn-bundle`]: bin/pgxn-bundle
  [`pgxn-release`]: bin/pgxn-release
  [PostgreSQL Apt]: https://wiki.postgresql.org/wiki/Apt
  [back to 8.4]: http://apt.postgresql.org/pub/repos/apt/dists/buster-pgdg/
  [GithHub Workflow]: https://help.github.com/en/actions/configuring-and-managing-workflows
  [create-release]: https://github.com/actions/create-release
  [upload-release-asset]: https://github.com/actions/upload-release-asset
  [PGXN]: https;//pgxn.org/ "The PostgreSQL Extension Network"
  [David E. Wheeler]: https://justatheory.com/
  [PostgreSQL License]: https://opensource.org/licenses/PostgreSQL
  [LICENSE]: LICENSE
  [the docs]: https://pgxn.github.io/pgxnclient/