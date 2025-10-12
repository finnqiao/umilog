# Phase 0–4 (Reference DDL)
# This is the same DDL provided in the proposal, stored for reference / future PostGIS path.

CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pg_trgm;

DO $$ BEGIN
  CREATE TYPE site_type AS ENUM ('reef','wreck','cave','other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE entry_type AS ENUM ('boat','shore');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE likelihood AS ENUM ('common','occasional','rare');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  CREATE TYPE license_type AS ENUM ('ODbL','CC0','OGL','PublicDomain','Other');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- Regions
CREATE TABLE IF NOT EXISTS region (
  region_id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  country_code CHAR(2),
  geom GEOMETRY(MULTIPOLYGON,4326) NOT NULL
);
CREATE INDEX IF NOT EXISTS region_gix ON region USING GIST (geom);

-- Areas
CREATE TABLE IF NOT EXISTS area (
  area_id SERIAL PRIMARY KEY,
  region_id INT REFERENCES region(region_id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  slug TEXT UNIQUE,
  rank SMALLINT DEFAULT 0,
  geom GEOMETRY(MULTIPOLYGON,4326),
  centroid GEOMETRY(POINT,4326)
);
CREATE INDEX IF NOT EXISTS area_gix ON area USING GIST (geom);
CREATE INDEX IF NOT EXISTS area_centroid_gix ON area USING GIST (centroid);

-- Sites
CREATE TABLE IF NOT EXISTS site (
  site_id BIGSERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  type site_type DEFAULT 'other',
  entry_type entry_type,
  is_protected BOOLEAN DEFAULT FALSE,
  depth_min_m INT,
  depth_max_m INT,
  description TEXT,
  tags TEXT[] DEFAULT '{}',
  popularity SMALLINT DEFAULT 0,
  region_id INT REFERENCES region(region_id) ON DELETE SET NULL,
  area_id INT REFERENCES area(area_id) ON DELETE SET NULL,
  geom GEOMETRY(POINT,4326) NOT NULL,
  geohash6_gen TEXT GENERATED ALWAYS AS (ST_GeoHash(geom,6)) STORED,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  verified BOOLEAN DEFAULT FALSE,
  source_confidence SMALLINT DEFAULT 0
);
CREATE INDEX IF NOT EXISTS site_gix        ON site USING GIST (geom);
CREATE INDEX IF NOT EXISTS site_geohash6   ON site(geohash6_gen);
CREATE INDEX IF NOT EXISTS site_region_idx ON site(region_id);
CREATE INDEX IF NOT EXISTS site_area_idx   ON site(area_id);
CREATE INDEX IF NOT EXISTS site_pop_idx    ON site(popularity);
CREATE INDEX IF NOT EXISTS site_tags_gin   ON site USING GIN (tags);
CREATE INDEX IF NOT EXISTS site_name_trgm  ON site USING GIN (name gin_trgm_ops);
CREATE INDEX IF NOT EXISTS site_fts_idx    ON site USING GIN (to_tsvector('simple', coalesce(name,'')||' '||coalesce(description,'')));

CREATE OR REPLACE FUNCTION set_updated_at() RETURNS trigger AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END $$ LANGUAGE plpgsql;
DO $$ BEGIN
  CREATE TRIGGER trg_site_updated BEFORE UPDATE ON site FOR EACH ROW EXECUTE PROCEDURE set_updated_at();
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ... (rest of DDL omitted here for brevity; see proposal)
