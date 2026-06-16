-- Gold fact: per-channel snapshot metrics.
CREATE OR REPLACE TABLE `{{ params.project }}.gold.fact_channel_metrics` AS
SELECT
  FARM_FINGERPRINT(LOWER(channel_name))    AS channel_key,
  FARM_FINGERPRINT(LOWER(IFNULL(country, '?'))) AS country_key,
  FARM_FINGERPRINT(LOWER(CONCAT(IFNULL(category, '?'), '|', IFNULL(channel_type, '?')))) AS category_key,
  load_date,
  rank                       AS overall_rank,
  subscribers,
  video_views,
  uploads,
  subscribers_last_30_days,
  video_views_last_30_days,
  lowest_monthly_earnings,
  highest_monthly_earnings,
  lowest_yearly_earnings,
  highest_yearly_earnings,
  SAFE_DIVIDE(video_views, NULLIF(subscribers, 0)) AS views_per_subscriber,
  SAFE_DIVIDE(video_views, NULLIF(uploads, 0))     AS avg_views_per_upload
FROM `{{ params.project }}.silver.stg_channel`;
