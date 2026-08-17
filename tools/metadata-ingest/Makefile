# The whole workflow. `make` does everything, safely, from any state.
#
#   make            import every local dump + TMDB's free daily id dumps
#   make import     local dumps only, no network
#   make exports    TMDB daily id dumps — breadth, zero API calls
#   make tmdb       detail fetch. LAZY: needs TITLES= or LIMIT=
#   make omdb       RT + Metacritic. LAZY, 1000/day, needs OMDB_API_KEY
#   make stats      what is in the record right now
#   make rederive   rebuild derived tables from raw — no network, no quota
#   make fresh      delete and rebuild; refuses if fetched payloads would be lost
#   make test       regression suite (no network, no dumps needed)
#   make imdb       IMDb's official dumps: every rating, one download, no API
#   make docs       build the JSON documents the client will receive
#   make backup     two tiers, and only when it is worth a commit
#   make restore    reload the committed set into an empty record
#
# Every target is re-runnable. Stopping a fetch halfway and re-running loses
# nothing: `fetch_log` remembers which questions already have answers.

PY ?= python3
DB ?= data/record.db
LIMIT ?=

.PHONY: all import exports imdb tmdb omdb test stats rederive fresh backup backup-force docs restore clean

all: import exports imdb stats

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

# 1000 requests/day: there is no sweep mode, by construction.
omdb:
ifdef TITLES
	$(PY) fetch_omdb.py --db $(DB) --titles $(TITLES)
else ifdef LIMIT
	$(PY) fetch_omdb.py --db $(DB) --limit $(LIMIT)
else
	@echo "say what to fetch:  make omdb LIMIT=200   |   make omdb TITLES=41,905"
	@exit 1
endif

test:
	@$(PY) tests.py

stats:
	@$(PY) ingest.py --db $(DB) --stats

rederive:
	$(PY) ingest.py --db $(DB) --rederive

fresh:
	$(PY) ingest.py --db $(DB) --fresh

# Two tiers: `backup/` is committed and small, `data/` is not and is large.
# Decides for itself: skips unless the schema moved or the map grew.
backup:
	@$(PY) backup.py --db $(DB) --if-worth-it

backup-force:
	@$(PY) backup.py --db $(DB)

docs:
	$(PY) document.py --db $(DB) --export data/documents $(if $(LIMIT),--limit $(LIMIT))

restore:
	@$(PY) backup.py --db $(DB) --restore

imdb:
	$(PY) import_imdb_datasets.py --db $(DB)

clean:
	rm -f $(DB) $(DB)-wal $(DB)-shm
