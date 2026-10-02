-- Type 1 global dictionaries. Snapshot facts preserve historical country/category.
CREATE TABLE IF NOT EXISTS `{{ params.project }}.gold.dim_country` (
 country_key STRING, country STRING, country_code STRING, population NUMERIC,
 urban_population NUMERIC, unemployment_rate FLOAT64, education_enrollment_pct FLOAT64,
 latitude FLOAT64, longitude FLOAT64, last_snapshot DATE
);
MERGE `{{ params.project }}.gold.dim_country` t USING (
 SELECT TO_HEX(SHA256(LOWER(country))) country_key, country, country_code,
 country_population population, country_urban_population urban_population,
 country_unemployment_rate unemployment_rate, education_enrollment_pct,
 country_latitude latitude, country_longitude longitude, snapshot_date last_snapshot
 FROM `{{ params.project }}.silver.stg_channel` WHERE snapshot_date=@snapshot_date
 QUALIFY ROW_NUMBER() OVER (PARTITION BY LOWER(country) ORDER BY channel_key)=1
) s ON t.country_key=s.country_key
WHEN MATCHED AND s.last_snapshot>=t.last_snapshot THEN UPDATE SET
 country=s.country, country_code=s.country_code, population=s.population,
 urban_population=s.urban_population, unemployment_rate=s.unemployment_rate,
 education_enrollment_pct=s.education_enrollment_pct, latitude=s.latitude,
 longitude=s.longitude, last_snapshot=s.last_snapshot
WHEN NOT MATCHED THEN INSERT ROW;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.gold.dim_category` (
 category_key STRING, category STRING, channel_type STRING
);
MERGE `{{ params.project }}.gold.dim_category` t USING (
 SELECT DISTINCT TO_HEX(SHA256(TO_JSON_STRING(STRUCT(LOWER(category) AS category, LOWER(channel_type) AS channel_type)))) category_key,
 category, channel_type FROM `{{ params.project }}.silver.stg_channel` WHERE snapshot_date=@snapshot_date
 QUALIFY ROW_NUMBER() OVER (PARTITION BY LOWER(category), LOWER(channel_type) ORDER BY category, channel_type)=1
) s ON t.category_key=s.category_key WHEN NOT MATCHED THEN INSERT ROW;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.gold.dim_channel` (
 channel_key STRING, channel_name STRING, channel_title STRING, country_key STRING,
 category_key STRING, created_year FLOAT64, created_month STRING, created_day FLOAT64, last_snapshot DATE
);
MERGE `{{ params.project }}.gold.dim_channel` t USING (
 SELECT channel_key, channel_name, channel_title, TO_HEX(SHA256(LOWER(country))) country_key,
 TO_HEX(SHA256(TO_JSON_STRING(STRUCT(LOWER(category) AS category, LOWER(channel_type) AS channel_type)))) category_key,
 created_year, created_month, created_day, snapshot_date last_snapshot
 FROM `{{ params.project }}.silver.stg_channel` WHERE snapshot_date=@snapshot_date
) s ON t.channel_key=s.channel_key
WHEN MATCHED AND s.last_snapshot>=t.last_snapshot THEN UPDATE SET
 channel_name=s.channel_name, channel_title=s.channel_title, country_key=s.country_key,
 category_key=s.category_key, created_year=s.created_year, created_month=s.created_month,
 created_day=s.created_day, last_snapshot=s.last_snapshot
WHEN NOT MATCHED THEN INSERT ROW;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.gold.dim_date` (
 date_key DATE, calendar_year INT64, calendar_month INT64, calendar_day INT64
);
MERGE `{{ params.project }}.gold.dim_date` t USING (
 SELECT @snapshot_date date_key, EXTRACT(YEAR FROM @snapshot_date) calendar_year,
 EXTRACT(MONTH FROM @snapshot_date) calendar_month, EXTRACT(DAY FROM @snapshot_date) calendar_day
) s ON t.date_key=s.date_key WHEN NOT MATCHED THEN INSERT ROW;
