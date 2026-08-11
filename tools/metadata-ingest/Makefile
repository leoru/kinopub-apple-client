# The whole workflow. `make` does everything, safely, from any state.
#
#   make            import every local dump + TMDB's free daily id dumps
#   make import     local dumps only, no network
#   make exports    TMDB daily id dumps — breadth, zero API calls
#   make tmdb       detail fetch. LAZY: needs TITLES= or LIMIT=
#   make stats      what is in the record right now
#   make fresh      rebuild from zero
#   make backup     SQL dump, for git
#
# Every target is re-runnable. Stopping a fetch halfway and re-running loses
# nothing: `fetch_log` remembers which questions already have answers.

PY ?= python3
DB ?= data/record.db
LIMIT ?=

.PHONY: all import exports tmdb stats fresh backup clean

all: import exports stats

import:
	$(PY) ingest.py --db $(DB) $(if $(LIMIT),--limit $(LIMIT))

exports:
	$(PY) fetch_tmdb_exports.py --db $(DB)

# Detail fetch is never part of `make all`: it spends a personal token per
# title. Ask for exactly what you want.
tmdb:
ifdef TITLES
	$(PY) fetch_tmdb.py --db $(DB) --titles $(TITLES)
else ifdef LIMIT
	$(PY) fetch_tmdb.py --db $(DB) --limit $(LIMIT)
else
	@echo "say what to fetch:  make tmdb LIMIT=200   |   make tmdb TITLES=41,905"
	@echo "the whole backlog is a deliberate act:  python3 fetch_tmdb.py --sweep --yes"
	@exit 1
endif

stats:
	@$(PY) ingest.py --db $(DB) --stats

fresh:
	$(PY) ingest.py --db $(DB) --fresh

# Text, so git can diff and compress it. The record itself stays untracked.
backup:
	@mkdir -p data
	sqlite3 $(DB) .dump | gzip -9 > data/record-$$(date -u +%Y%m%d).sql.gz
	@ls -lh data/record-*.sql.gz | tail -1

clean:
	rm -f $(DB) $(DB)-wal $(DB)-shm
