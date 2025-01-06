EXTENSION    = hello
EXTVERSION   = 0.1.0
TESTS        = test/sql/base.sql
REGRESS      = base
REGRESS_OPTS = --inputdir=test --load-extension=$(EXTENSION)
PG_CONFIG    = pg_config

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

.PHONY: upgrade-pgrx # Upgrade to the current version of PGRX.
upgrade-pgrx:
	cargo pgrx upgrade

.PHONY: install-pgrx # Install the version of PGRX listed in Cargo.toml
install-pgrx: Cargo.toml
	cargo install cargo-pgrx --version "$$(perl -nE '/^pgrx\s+=\s"=?([^"]+)/ && do { say $$1; exit }' Cargo.toml)" --locked

.PHONY: pgrx-init # Initialize pgrx for the PostgreSQL version identified by pg_config.
pgrx-init: Cargo.toml
	@cargo pgrx init "--pg$$(perl -E 'shift =~ /(\d+)/ && say $$1' "$$($(PG_CONFIG) --version)")"="$(PG_CONFIG)"

.PHONY: test # Run the full test suite against the PostgreSQL version identified by pg_config.
test:
	@cargo test --all --no-default-features --features "pg$(PGV) pg_test" -- --nocapture

package:
	@cargo pgrx package --pg-config "$(PG_CONFIG)"
