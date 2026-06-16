-- Gold marts: BI-ready aggregations on top of facts + dims.

-- Top channels per country by subscriber count.
CREATE OR REPLACE TABLE `{{ params.project }}.gold.mart_top_channels_by_country` AS
SELECT
  c.country,
  c.country_code,
  ch.channel_name,
  cat.category,
  cat.channel_type,
  f.subscribers,
  f.video_views,
  f.uploads,
  ROW_NUMBER() OVER (PARTITION BY c.country ORDER BY f.subscribers DESC) AS country_rank
FROM `{{ params.project }}.gold.fact_channel_metrics` f
JOIN `{{ params.project }}.gold.dim_channel`  ch  ON ch.channel_key  = f.channel_key
JOIN `{{ params.project }}.gold.dim_country`  c   ON c.country_key   = f.country_key
JOIN `{{ params.project }}.gold.dim_category` cat ON cat.category_key = f.category_key
QUALIFY country_rank <= 10;

-- Aggregated country-level performance.
CREATE OR REPLACE TABLE `{{ params.project }}.gold.mart_country_performance` AS
SELECT
  c.country,
  c.country_code,
  c.population,
  COUNT(*)                          AS channel_count,
  SUM(f.subscribers)                AS total_subscribers,
  SUM(f.video_views)                AS total_video_views,
  SAFE_DIVIDE(SUM(f.subscribers), c.population) AS subscribers_per_capita,
  AVG(f.views_per_subscriber)       AS avg_views_per_subscriber
FROM `{{ params.project }}.gold.fact_channel_metrics` f
JOIN `{{ params.project }}.gold.dim_country` c USING (country_key)
GROUP BY c.country, c.country_code, c.population;

-- Category-level performance (which content type wins).
CREATE OR REPLACE TABLE `{{ params.project }}.gold.mart_category_performance` AS
SELECT
  cat.category,
  cat.channel_type,
  COUNT(*)               AS channel_count,
  SUM(f.subscribers)     AS total_subscribers,
  SUM(f.video_views)     AS total_video_views,
  AVG(f.subscribers)     AS avg_subscribers,
  AVG(f.avg_views_per_upload) AS avg_views_per_upload
FROM `{{ params.project }}.gold.fact_channel_metrics` f
JOIN `{{ params.project }}.gold.dim_category` cat USING (category_key)
GROUP BY cat.category, cat.channel_type;
