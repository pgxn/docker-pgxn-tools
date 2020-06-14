EXTENSION    = widget
EXTVERSION   = 1.0.0
DATA         = widget.sql
TESTS        = test/sql/base.sql
REGRESS      = base
REGRESS_OPTS = --inputdir=test
PG_CONFIG    = pg_config

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)
