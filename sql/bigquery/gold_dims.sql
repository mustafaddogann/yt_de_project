-- Gold dimensions. Country and category are the two natural axes.
CREATE OR REPLACE TABLE `{{ params.project }}.gold.dim_country` AS
SELECT
  FARM_FINGERPRINT(LOWER(country)) AS country_key,
  country,
  ANY_VALUE(country_code)               AS country_code,
  MAX(country_population)               AS population,
  MAX(country_urban_population)         AS urban_population,
  AVG(country_unemployment_rate)        AS unemployment_rate,
  AVG(education_enrollment_pct)         AS education_enrollment_pct,
  AVG(country_latitude)                 AS latitude,
  AVG(country_longitude)                AS longitude
FROM `{{ params.project }}.silver.stg_channel`
WHERE country IS NOT NULL
GROUP BY country;

CREATE OR REPLACE TABLE `{{ params.project }}.gold.dim_category` AS
SELECT
  FARM_FINGERPRINT(LOWER(CONCAT(IFNULL(category, '?'), '|', IFNULL(channel_type, '?')))) AS category_key,
  category,
  channel_type
FROM `{{ params.project }}.silver.stg_channel`
WHERE category IS NOT NULL OR channel_type IS NOT NULL
GROUP BY category, channel_type;

CREATE OR REPLACE TABLE `{{ params.project }}.gold.dim_channel` AS
SELECT
  FARM_FINGERPRINT(LOWER(channel_name))    AS channel_key,
  channel_name,
  channel_title,
  FARM_FINGERPRINT(LOWER(IFNULL(country, '?'))) AS country_key,
  FARM_FINGERPRINT(LOWER(CONCAT(IFNULL(category, '?'), '|', IFNULL(channel_type, '?')))) AS category_key,
  created_year,
  created_month,
  created_day
FROM `{{ params.project }}.silver.stg_channel`;
