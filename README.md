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

[`pgxn`]: https://github.com/pgxn/pgxnclient
[`pg-start`]: bin/pg-start
[`pg-build-test`]: bin/pg-build-test
[PostgreSQL Apt]: https://wiki.postgresql.org/wiki/Apt
[back to 8.4]: http://apt.postgresql.org/pub/repos/apt/dists/buster-pgdg/
