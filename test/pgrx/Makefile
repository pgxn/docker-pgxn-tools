EXTENSION    = hello
EXTVERSION   = 0.1.0
TESTS        = test/sql/base.sql
REGRESS      = base
REGRESS_OPTS = --inputdir=test --load-extension=$(EXTENSION)
PG_CONFIG    = pg_config

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
