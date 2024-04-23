EXTENSION    = widget
EXTVERSION   = 1.0.0
DATA         = $(EXTENSION)--$(EXTVERSION).sql
TESTS        = test/sql/base.sql
REGRESS      = base
REGRESS_OPTS = --inputdir=test
PG_CONFIG    = pg_config

PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

all: $(EXTENSION)--$(EXTVERSION).sql

$(EXTENSION)--$(EXTVERSION).sql: $(EXTENSION).sql
	@cp $^ $@
