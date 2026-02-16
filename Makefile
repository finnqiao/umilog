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

# ============================================================
# v5: Extended Data Pipeline for Reference Database Enhancement
# ============================================================

# Fetch OSM dive sites for underrepresented regions (split into smaller queries)
.PHONY: osm-sites-fetch
osm-sites-fetch: dirs
	@echo "Fetching OSM dive sites for underrepresented regions..."
	@echo "  -> SE Asia West (Indonesia/Malaysia)..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_se_asia_west.overpassql \
	  -o $(RAW_DIR)/sites_se_asia_west.json
	@sleep 10
	@echo "  -> SE Asia East (Philippines/Papua)..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_se_asia_east.overpassql \
	  -o $(RAW_DIR)/sites_se_asia_east.json
	@sleep 10
	@echo "  -> Thailand/Vietnam..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_thailand.overpassql \
	  -o $(RAW_DIR)/sites_thailand.json
	@sleep 10
	@echo "  -> Japan..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_japan.overpassql \
	  -o $(RAW_DIR)/sites_japan.json
	@sleep 10
	@echo "  -> Pacific..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_pacific.overpassql \
	  -o $(RAW_DIR)/sites_pacific.json
	@sleep 10
	@echo "  -> Maldives..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_maldives.overpassql \
	  -o $(RAW_DIR)/sites_maldives.json
	@sleep 10
	@echo "  -> Central America..."
	curl -sS --retry 3 --retry-delay 10 --max-time 300 -X POST https://overpass-api.de/api/interpreter \
	  -d @data/queries/overpass_sites_central_america.overpassql \
	  -o $(RAW_DIR)/sites_central_america.json
	@echo "Saved OSM site dumps to $(RAW_DIR)"

# Build OSM sites into seed format
.PHONY: osm-sites-build
osm-sites-build: dirs
	python3 data/scripts/osm_sites_to_json.py $(RAW_DIR) $(EXPORT_DIR)/sites_osm.json

# Fetch species taxonomy from WoRMS (rate limited - takes ~10 min)
.PHONY: species-taxonomy-fetch
species-taxonomy-fetch: dirs
	@echo "Fetching species taxonomy from WoRMS (this takes ~10 minutes)..."
	python3 data/scripts/worms_taxonomy_fetch.py $(RAW_DIR)/worms_families.json

# Fetch species occurrences from GBIF (rate limited - takes ~5 min)
.PHONY: species-gbif-fetch
species-gbif-fetch: dirs
	@echo "Fetching species occurrences from GBIF..."
	python3 data/scripts/gbif_species_fetch.py $(RAW_DIR)/gbif_species.json

# Build unified species catalog
.PHONY: species-build
species-build: dirs
	python3 data/scripts/species_to_seed.py \
	  $(RAW_DIR)/worms_families.json \
	  $(RAW_DIR)/gbif_species.json \
	  $(EXPORT_DIR)

# Build geographic hierarchy from sites
.PHONY: geo-hierarchy-build
geo-hierarchy-build: dirs
	python3 data/scripts/geographic_hierarchy.py \
	  $(EXPORT_DIR)/sites_merged.json \
	  $(EXPORT_DIR)

# Link species to sites using GBIF/OBIS occurrence data
.PHONY: site-species-link
site-species-link: dirs
	@echo "Linking species to sites (this takes a while due to API rate limits)..."
	python3 data/scripts/site_species_linker.py \
	  $(EXPORT_DIR)/sites_validated.json \
	  $(EXPORT_DIR)/species_catalog_v2.json \
	  $(EXPORT_DIR)/site_species.json

# Validate and deduplicate all data
.PHONY: data-validate
data-validate: dirs
	python3 data/scripts/data_validator.py $(EXPORT_DIR)

# Link sites to geographic hierarchy (country_id, region_id)
.PHONY: sites-link-hierarchy
sites-link-hierarchy: dirs
	python3 data/scripts/link_sites_to_hierarchy.py $(EXPORT_DIR)/sites_merged.json $(EXPORT_DIR)/sites_linked.json

# Add location qualifiers to duplicate names
.PHONY: sites-add-qualifiers
sites-add-qualifiers: dirs
	python3 data/scripts/add_location_qualifiers.py $(EXPORT_DIR)/sites_linked.json $(EXPORT_DIR)/sites_qualified.json

# Merge species catalogs (v1 curated + v2 GBIF)
.PHONY: species-merge
species-merge: dirs
	python3 data/scripts/merge_species_catalogs.py \
		Resources/SeedData/species_catalog.json \
		$(EXPORT_DIR)/species_catalog_v2.json \
		$(EXPORT_DIR)/families_catalog.json \
		$(EXPORT_DIR)/species_catalog_merged.json
	cp $(EXPORT_DIR)/species_catalog_merged.json $(EXPORT_DIR)/species_catalog_v2.json

# Merge all site sources into one file
.PHONY: sites-merge
sites-merge: dirs
	@echo "Merging site sources..."
	python3 data/scripts/merge_sites.py $(EXPORT_DIR)/sites_merged.json $(SEED_OUT) $(EXPORT_DIR)/sites_osm.json

# Full reference database build pipeline
.PHONY: refdb-build-all
refdb-build-all: wd-fetch osm-sites-fetch osm-sites-build wd-build-seed sites-merge geo-hierarchy-build species-taxonomy-fetch species-gbif-fetch species-build data-validate
	@echo ""
	@echo "=== Reference Database Build Complete ==="
	@echo "Next steps:"
	@echo "  1. Run 'make site-species-link' to create species-site associations"
	@echo "  2. Copy seed files to Resources/SeedData/"
	@echo ""

# Copy exports to app seed directory
.PHONY: seed-deploy
seed-deploy:
	@echo "Deploying seed files to Resources/SeedData/..."
	cp $(EXPORT_DIR)/countries.json Resources/SeedData/
	cp $(EXPORT_DIR)/regions.json Resources/SeedData/
	cp $(EXPORT_DIR)/areas.json Resources/SeedData/
	cp $(EXPORT_DIR)/families_catalog.json Resources/SeedData/
	cp $(EXPORT_DIR)/species_catalog_v2.json Resources/SeedData/
	cp $(EXPORT_DIR)/site_species.json Resources/SeedData/
	@echo "Seed files deployed"

# ============================================================
# Site Images Pipeline (Wikimedia Commons → Cloudflare R2)
# ============================================================

IMAGES_DIR=$(PWD)/data/images

# Fetch images from Wikimedia Commons
.PHONY: images-fetch
images-fetch: dirs
	@echo "Fetching site images from Wikimedia Commons..."
	@echo "This downloads ~1000 images and may take 10-15 minutes."
	python3 data/scripts/site_images_fetch.py $(EXPORT_DIR)/sites_validated.json $(IMAGES_DIR)

# Upload images to Cloudflare R2
# Requires: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY
.PHONY: images-upload
images-upload:
	@echo "Uploading images to Cloudflare R2..."
	python3 data/scripts/upload_to_r2.py $(IMAGES_DIR)

# Deploy site_media seed file to app resources
.PHONY: images-deploy
images-deploy:
	@echo "Deploying site_media seed file..."
	cp $(IMAGES_DIR)/site_media_seed.json Resources/SeedData/site_media.json
	@echo "Deployed to Resources/SeedData/site_media.json"

# Full image pipeline: fetch → upload → deploy
.PHONY: images-all
images-all: images-fetch images-upload images-deploy
	@echo "Image pipeline complete!"

# Clean generated files
.PHONY: clean-data
clean-data:
	rm -rf $(RAW_DIR)/*.json $(STAGE_DIR)/*.json $(EXPORT_DIR)/*.json
	@echo "Cleaned data directories"

.PHONY: clean-images
clean-images:
	rm -rf $(IMAGES_DIR)
	@echo "Cleaned images directory"

# ============================================================
# Pre-bundled Seed Database Generation
# ============================================================

SEED_DB_DIR=$(PWD)/Resources/SeedDB
SEED_DB_OUTPUT=$(SEED_DB_DIR)/umilog_seed.db

# Generate pre-seeded SQLite database for app bundle
# This eliminates JSON parsing and individual inserts at runtime
.PHONY: seed-db-generate
seed-db-generate:
	@echo "Generating pre-seeded database..."
	@mkdir -p $(SEED_DB_DIR)
	python3 scripts/generate_seed_db.py $(SEED_DB_OUTPUT)
	@echo "Generated: $(SEED_DB_OUTPUT)"
	@ls -lh $(SEED_DB_OUTPUT)

# Clean generated seed database
.PHONY: clean-seed-db
clean-seed-db:
	rm -rf $(SEED_DB_DIR)
	@echo "Cleaned seed database directory"

# Full build including seed database
.PHONY: build-with-seed-db
build-with-seed-db: seed-db-generate
	xcodegen generate
	@echo "Ready to build with pre-seeded database"
