CREATE TEMP TABLE selected AS
SELECT
  channel_key,
  NULLIF(TRIM(youtuber), '') AS channel_name,
  NULLIF(TRIM(title), '') AS channel_title,
  COALESCE(NULLIF(TRIM(country), ''), 'Unknown') AS country,
  NULLIF(abbreviation, '') AS country_code,
  COALESCE(NULLIF(TRIM(category), ''), 'Unknown') AS category,
  COALESCE(NULLIF(TRIM(channel_type), ''), 'Unknown') AS channel_type,
  NULLIF(created_month, '') AS created_month,
  SAFE_CAST(NULLIF(rank, '') AS FLOAT64) AS rank,
  SAFE_CAST(NULLIF(subscribers, '') AS NUMERIC) AS subscribers,
  SAFE_CAST(NULLIF(video_views, '') AS NUMERIC) AS video_views,
  SAFE_CAST(NULLIF(uploads, '') AS NUMERIC) AS uploads,
  SAFE_CAST(NULLIF(video_views_rank, '') AS FLOAT64) AS video_views_rank,
  SAFE_CAST(NULLIF(country_rank, '') AS FLOAT64) AS country_rank,
  SAFE_CAST(NULLIF(channel_type_rank, '') AS FLOAT64) AS channel_type_rank,
  SAFE_CAST(NULLIF(video_views_for_the_last_30_days, '') AS NUMERIC) AS video_views_last_30_days,
  SAFE_CAST(NULLIF(lowest_monthly_earnings, '') AS NUMERIC) AS lowest_monthly_earnings,
  SAFE_CAST(NULLIF(highest_monthly_earnings, '') AS NUMERIC) AS highest_monthly_earnings,
  SAFE_CAST(NULLIF(lowest_yearly_earnings, '') AS NUMERIC) AS lowest_yearly_earnings,
  SAFE_CAST(NULLIF(highest_yearly_earnings, '') AS NUMERIC) AS highest_yearly_earnings,
  SAFE_CAST(NULLIF(subscribers_for_last_30_days, '') AS NUMERIC) AS subscribers_last_30_days,
  SAFE_CAST(NULLIF(created_year, '') AS FLOAT64) AS created_year,
  SAFE_CAST(NULLIF(created_date, '') AS FLOAT64) AS created_day,
  SAFE_CAST(NULLIF(gross_tertiary_education_enrollment, '') AS FLOAT64) AS education_enrollment_pct,
  SAFE_CAST(NULLIF(population, '') AS NUMERIC) AS country_population,
  SAFE_CAST(NULLIF(unemployment_rate, '') AS FLOAT64) AS country_unemployment_rate,
  SAFE_CAST(NULLIF(urban_population, '') AS NUMERIC) AS country_urban_population,
  SAFE_CAST(NULLIF(latitude, '') AS FLOAT64) AS country_latitude,
  SAFE_CAST(NULLIF(longitude, '') AS FLOAT64) AS country_longitude,
  snapshot_date,
  run_id,
  source_checksum,
  ingestion_timestamp
FROM `{{ params.project }}.bronze.raw_youtube_stats`
WHERE snapshot_date=@snapshot_date AND source_checksum=@checksum
QUALIFY ROW_NUMBER() OVER (PARTITION BY channel_key, snapshot_date ORDER BY ingestion_timestamp DESC, run_id DESC)=1;
ASSERT (SELECT COUNT(*) FROM selected)=@expected_rows AS 'Silver row loss';
CREATE TABLE IF NOT EXISTS `{{ params.project }}.silver.stg_channel`
PARTITION BY snapshot_date CLUSTER BY channel_key AS SELECT * FROM selected WHERE FALSE;
BEGIN TRANSACTION;
DELETE FROM `{{ params.project }}.silver.stg_channel` WHERE snapshot_date=@snapshot_date;
INSERT INTO `{{ params.project }}.silver.stg_channel` SELECT * FROM selected;
COMMIT TRANSACTION;
