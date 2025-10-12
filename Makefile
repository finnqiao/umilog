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

# Fetch OSM dive shops for multiple regions via Overpass
.PHONY: shops-fetch
shops-fetch: dirs
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_red_sea.overpassql     -o $(RAW_DIR)/shops_red_sea.json
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_caribbean.overpassql   -o $(RAW_DIR)/shops_caribbean.json
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_se_asia.overpassql     -o $(RAW_DIR)/shops_se_asia.json
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_mediterranean.overpassql -o $(RAW_DIR)/shops_mediterranean.json
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_aus.overpassql        -o $(RAW_DIR)/shops_aus.json
	curl -sS -X POST https://overpass-api.de/api/interpreter -d @data/queries/overpass_shops_japan.overpassql      -o $(RAW_DIR)/shops_japan.json
	@echo "Saved OSM shop dumps to $(RAW_DIR)"

# Build consolidated shops export JSON
.PHONY: shops-build
shops-build: dirs
	python3 data/scripts/osm_shops_to_json.py $(RAW_DIR)/shops_*.json $(EXPORT_DIR)/shops.json

.PHONY: build-all
build-all: wd-fetch wd-build-seed shops-fetch shops-build
