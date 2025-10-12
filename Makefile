RAW_DIR=$(PWD)/data/raw
STAGE_DIR=$(PWD)/data/stage
EXPORT_DIR=$(PWD)/data/export
SEED_OUT=$(PWD)/Resources/SeedData/sites_wikidata.json

# Ensure directories
.PHONY: dirs
dirs:
	mkdir -p $(RAW_DIR) $(STAGE_DIR) $(EXPORT_DIR)

# Fetch Wikidata dive sites into raw JSON
.PHONY: wd-fetch
wd-fetch: dirs
	curl -sS -G \
	  --data-urlencode "format=json" \
	  --data-urlencode "query@data/queries/dive_sites_wd.sparql" \
	  https://query.wikidata.org/sparql \
	  -o $(RAW_DIR)/wd_dives.json
	@echo "Saved: $(RAW_DIR)/wd_dives.json"

# Build app seed JSON from WD JSON
.PHONY: wd-build-seed
wd-build-seed: dirs
	python3 data/scripts/wd_to_seed.py $(RAW_DIR)/wd_dives.json $(SEED_OUT)
	@echo "Saved: $(SEED_OUT)"

.PHONY: build-all
build-all: wd-fetch wd-build-seed
