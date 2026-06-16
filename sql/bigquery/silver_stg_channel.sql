-- Silver: cleaned, typed, deduplicated channel snapshot.
-- Source: bronze.raw_youtube_stats (one snapshot CSV per load_date).
CREATE OR REPLACE TABLE `{{ params.project }}.silver.stg_channel` AS
WITH ranked AS (
  SELECT
    rank,
    NULLIF(TRIM(youtuber), '')   AS channel_name,
    NULLIF(TRIM(title), '')      AS channel_title,
    NULLIF(TRIM(category), '')   AS category,
    NULLIF(TRIM(channel_type), '') AS channel_type,
    NULLIF(TRIM(country), '')    AS country,
    NULLIF(TRIM(abbreviation), '') AS country_code,
    CAST(subscribers AS INT64)   AS subscribers,
    CAST(video_views AS INT64)   AS video_views,
    CAST(uploads AS INT64)       AS uploads,
    CAST(video_views_for_the_last_30_days AS INT64) AS video_views_last_30_days,
    CAST(subscribers_for_last_30_days AS INT64) AS subscribers_last_30_days,
    lowest_monthly_earnings,
    highest_monthly_earnings,
    lowest_yearly_earnings,
    highest_yearly_earnings,
    CAST(created_year AS INT64)  AS created_year,
    NULLIF(TRIM(created_month), '') AS created_month,
    CAST(created_date AS INT64)  AS created_day,
    gross_tertiary_education_enrollment AS education_enrollment_pct,
    CAST(population AS INT64)    AS country_population,
    unemployment_rate            AS country_unemployment_rate,
    CAST(urban_population AS INT64) AS country_urban_population,
    latitude                     AS country_latitude,
    longitude                    AS country_longitude,
    load_date,
    ROW_NUMBER() OVER (
      PARTITION BY LOWER(TRIM(youtuber))
      ORDER BY load_date DESC, rank ASC
    ) AS rn
  FROM `{{ params.project }}.bronze.raw_youtube_stats`
  WHERE youtuber IS NOT NULL
)
SELECT * EXCEPT (rn) FROM ranked WHERE rn = 1;
