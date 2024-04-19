PGXN Extension Build and Test Tools Docker Image
================================================

[![Test & Release Status](https://github.com/pgxn/docker-pgxn-tools/workflows/CI/CD/badge.svg)](https://github.com/pgxn/docker-pgxn-tools/actions)

This project provides a simple Docker image to enable the automated testing of
PGXN extensions against multiple versions of PostgreSQL, as well as publishing
releases to PGXN. The image contains these utilities:

*   [`pgxn`][cli]: The PGXN command-line client
*   [`pg_prove`]: Runs and harnessing pgTAP tests
*   [`pg-start`] Pass a PostgreSQL major version to install and starts a PostgreSQL cluster
*   [`pg-build-test`]: Builds and tests an extension in the current directory
*   [`pgrx-build-test`]: Builds and tests a [pgrx] extension in the current directory
*   [`pgxn-bundle`]: Validates the PGXN META.json file and bundles up a release
*   [`pgxn-release`]: Release to PGXN

The image is based on the Debian Bookworm Slim image, and uses the
[PostgreSQL Apt] repository to install PostgreSQL, supporting versions
[back to 8.2], as well as the latest prerelease version.

Running a Container
-------------------

To run pgxn-tools in Docker, use the standard Docker CLI, like so:

``` sh
docker run -it --rm -w /repo --volume "$PWD:/repo" pgxn/pgxn-tools \
    sh -c 'pg-start 16 && pg-build-test'
```

This example mounts the current directory inside the container. Once inside, it
starts Postgres 16 then builds and runs the tests for the extension in that
directory.

### Unprivileged User

By default the container runs as `root`. To run as an unprivileged user, pass
the `AS_USER` environment variable and a user with that name will be created
with `sudo` privileges (already used by `pg-start`, `pg-build-test`, and
`pgrx-build-test`):

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

### Sudo-Enabled Users

The `nobody` user, included in the image, and the `postgres` user, created by
`pg-start`, also have full permission to use `sudo` without a password prompt.

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
        uses: actions/checkout@v4
      - name: Test on PostgreSQL ${{ matrix.pg }}
        run: pg-build-test # or pgrx-build-test for a pgrx extension
```

This example demonstrates automatic publishing of a release whenever a tag is
pushed matching `v*`. It publishes both to GitHub (using the [create-release]
and [upload-release-asset] actions) and to PGXN:

``` yaml
name: Release
on:
  push:
    # Push events matching v1.0, v20.15.10, etc.
    tags: ['v[0-9]+.[0-9]+.[0-9]+']
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
      uses: actions/checkout@v4
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

### Unprivileged User Workflow

GitHub workflows [require the root user] to work with the workspace. To perform
tasks as an unprivileged user, first set things up as the root user, then use
[gosu] to execute a command as the `postgres` (can still run `sudo`) or `nobody`
(no privileges at all) user. For example:

``` yaml
    container: pgxn/pgxn-tools
    steps:
      - uses: actions/checkout@v4
      - run: pg-start 16
      - run: chown -R postgres:postgres .
      - run: gosu postgres pg-build-test
```

The checkout action, `pg-start`, and `chown` commands must run as `root`. Then,
with the current directory's files all owned the newly-created `postgres` user,
the last `run` commands executes `pg-build-test` as `postgres`, with the
necessary permissions to write files to the workspace directory.

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

For finer control over running the PostgreSQL cluster, set the `NO_CLUSTER`
environment variable to prevent `pg-start` from creating and starting a cluster:

```sh
env NO_CLUSTER=1 pg-start 14
```

This will simply install Postgres 14; to start it, use the [`pg_createcluster`]
command, like so:

```sh
pg_createcluster --start 14 my14 -p 5414 -- -A trust
```

This starts a cluster named "my14" on port 5414. This technique is useful to run
multiple clusters, even different versions at once; just given them unique names and
ports to run on:

```sh
env NO_CLUSTER=1 pg-start 15
pg_createcluster --start 15 my15 -p 5415 -- -A trust
env NO_CLUSTER=1 pg-start 16
pg_createcluster --start 16 my16 -p 5416 -- -A trust
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

By default, `pg-build-test` uses builds with `PROFILE=--Werror`; Specify an
alternate `$PROFILE` environment variable to override it:

``` sh
export PROFILE=--Wall
pg-build-test
```

### [`pgrx-build-test`]

``` sh
pgrx-build-test
```

Build, install, and test a PostgreSQL [pgrx] extension. It reads the required
version of [pgrx] from the `Cargo.toml` file, which must be v0.11.4 or higher.
Effectively the equivalent of:

``` sh
cargo install --locked cargo-pgrx --version ${PGRX_VERSION}
make cargo pgrx init --pg${PG_VERSION}=$(which pg_config)
cargo pgrx package --test --pg-config $(which pg_config)
cargo pgrx test --runas postgres pg$pgv
cargo pgrx install --test --pg-config $(which pg_config)
```

But a bit more, to ensure that the tests run as the `postgres` user and emits
all output. It will also run `make installcheck` if it finds a `Makefile` that
appears to define the `installcheck` target, and emit the contents of the
`regression.diffs` file if it fails.

**Note:** Since `pgrx` uses `sudo` to start the cluster as the `postgres`
user, so some environment variables may not be present while tests run. If
your Rust code reads environment variables it should guard against
`NotPresent` errors to handle unexpectedly missing environment variables.

### [`pgxn-bundle`]

``` sh
pgxn-bundle
PGXN_DIST_NAME=widget PGXN_DIST_VERSION=1.0.0 pgxn-bundle
```

Validates the PGXN `META.json` file and bundles up the repository for release
to PGXN. It does so by archiving the Git repository like so:

``` sh
git archive --format zip --prefix="${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}/" \
            --output "${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}" HEAD
```

If `pgxn-bundle` detects no Git repository, it uses `zip` to zip up entire
contents of the current directory with a command like this:

```sh
zip -r "${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}.zip" "${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}/"
```

If the `$PGXN_DIST_NAME` or `$PGXN_DIST_VERSION` variable is not set, the
extension name and version are read from the `META.json` file (indeed, this
is preferred). The zip file will be at the root of the repository, ready for
release, and the name of the bundle will be appended to the `$GITHUB_OUTPUT`
file in this format, for use in GitHub Actions such as [upload-release-asset]:

``` sh
echo bundle=${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}.zip >> $GITHUB_OUTPUT
```

To exclude Git repository files from the bundle, add a `.gitattributes` file to
the repository and use the `export-ignore` attribute to identify files and
directories to exclude. This example excludes some typical Git and GitHub files
and directories, as well as a test script:

```
.gitignore export-ignore
.gitattributes export-ignore
test.sh export-ignore
.github export-ignore
```

To include Git submodules in the bundle, set [`GIT_ARCHIVE_CMD=archive-all`]
and `pgxn-bundle` will use [git-archive-all] instead of `git archive` to create
the bundle.

Use the `$GIT_BUNDLE_OPTS` variable to pass options to the `git archive` (or
`git archive-all`) command or `$ZIP_BUNDLE_OPTS` to pass options to the `zip`
command.

For example, if a Git repo contains no `META.json`, but generates it via a
`make` command, it will not be included in the zip archive, because
`git archive` includes only committed files. Use the `--add-file` option to tell
`git archive` to add it, like so:

```sh
make META.json
export GIT_BUNDLE_OPTS="--add-file META.json"
pgxn-bundle
```

If, on the other hand, you're not using a Git repository, `pgxn-bundle` will use
the `zip` utility, instead. To exclude a file from the zip file, use the
`$ZIP_BUNDLE_OPTS` variable to pass the `--exclude` option to `zip`, something
like:

``` sh
export ZIP_BUNDLE_OPTS="--exclude */.dev-only.txt"
pgxn-bundle
```

Note the `*/` prefix, required to match a file name under the
`${PGXN_DIST_NAME}-${PGXN_DIST_VERSION}/` directory prefix.

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

Note that these are not the same as [PostgreSQL TAP] tests, though they are
also supported by the inclusion of IPC::Run in this image.

### Installed Packages

The image includes these packages; pass additional packages to
[`pg-start`](#pg-start) to install them while setting up PostgreSQL.

*   [build-essential](https://packages.debian.org/bookworm/build-essential)
*   [clang](https://packages.debian.org/bookworm/clang)
*   [llvm](https://packages.debian.org/bookworm/llvm)
*   [llvm-dev](https://packages.debian.org/bookworm/llvm-dev)
*   [llvm-runtime](https://packages.debian.org/bookworm/llvm-runtime)
*   [cmake](https://packages.debian.org/bookworm/cmake)
*   [pgxnclient](https://packages.debian.org/bookworm/pgxnclient)
*   [libtap-parser-sourcehandler-pgtap-perl](https://packages.debian.org/bookworm/libtap-parser-sourcehandler-pgtap-perl)
*   [sudo](https://packages.debian.org/bookworm/sudo)
*   [gosu](https://packages.debian.org/bookworm/gosu)
*   [ca-certificates](https://packages.debian.org/bookworm/ca-certificates)
*   [gnupg2](https://packages.debian.org/bookworm/gnupg2)
*   [zip](https://packages.debian.org/bookworm/zip)
*   [unzip](https://packages.debian.org/bookworm/unzip)
*   [libarchive-tools](https://packages.debian.org/bookworm/libarchive-tools)
*   [curl](https://packages.debian.org/bookworm/curl)
*   [git](https://packages.debian.org/bookworm/git)
*   [libicu-dev](https://packages.debian.org/bookworm/libicu-dev)
*   [libipc-run-perl](https://packages.debian.org/bookworm/libipc-run-perl)
    (IPC::Run for [PostgreSQL TAP] tests)
*   [libtest-simple-perl](https://packages.debian.org/bookworm/libtest-simple-perl)
*   [libxml2](https://packages.debian.org/bookworm/libxml2)
*   [locales](https://packages.debian.org/bookworm/locales)
*   [ssl-cert](https://packages.debian.org/bookworm/ssl-cert)
*   [git-archive-all](https://github.com/Kentzo/git-archive-all) (run `git archive-all`)

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
  [require the root user]: https://docs.github.com/en/actions/creating-actions/dockerfile-support-for-github-actions#user
  [GithHub Workflow]: https://help.github.com/en/actions/configuring-and-managing-workflows
  [gosu]: https://github.com/tianon/gosu
  [create-release]: https://github.com/actions/create-release
  [upload-release-asset]: https://github.com/actions/upload-release-asset
  [git-archive-all]: https://github.com/Kentzo/git-archive-all
  [PGXN]: https://pgxn.org/ "The PostgreSQL Extension Network"
  [`pg_createcluster`]: https://manpages.debian.org/buster/postgresql-common/pg_createcluster.1.en.html
  [David E. Wheeler]: https://justatheory.com/
  [PostgreSQL License]: https://opensource.org/licenses/PostgreSQL
  [LICENSE]: LICENSE
  [the docs]: https://pgxn.github.io/pgxnclient/
  [pgTAP]: https://pgtap.org/
  [PostgreSQL TAP]: https://www.postgresql.org/docs/current/regress-tap.html
  [TAP]: https://testanything.org "Test Anything Protocol"
  [pgrx]: https://github.com/pgcentralfoundation/pgrx
