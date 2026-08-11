# The whole workflow. `make` does everything, safely, from any state.
#
#   make            import every local dump, then fetch TMDB for what is missing
#   make import     dumps only, no network
#   make tmdb       TMDB only (resumes; already-answered ids are skipped)
#   make stats      what is in the record right now
#   make fresh      rebuild from zero
#   make backup     SQL dump, for git
#
# Every target is re-runnable. Stopping a fetch halfway and re-running loses
# nothing: `fetch_log` remembers which questions already have answers.

PY ?= python3
DB ?= data/record.db
LIMIT ?=

.PHONY: all import tmdb stats fresh backup clean

all: import tmdb stats

import:
	$(PY) ingest.py --db $(DB) $(if $(LIMIT),--limit $(LIMIT))

tmdb:
	$(PY) fetch_tmdb.py --db $(DB) $(if $(LIMIT),--limit $(LIMIT))

stats:
	@$(PY) ingest.py --db $(DB) --stats

fresh:
	$(PY) ingest.py --db $(DB) --fresh
	$(MAKE) tmdb

# Text, so git can diff and compress it. The record itself stays untracked.
backup:
	@mkdir -p data
	sqlite3 $(DB) .dump | gzip -9 > data/record-$$(date -u +%Y%m%d).sql.gz
	@ls -lh data/record-*.sql.gz | tail -1

clean:
	rm -f $(DB) $(DB)-wal $(DB)-shm
