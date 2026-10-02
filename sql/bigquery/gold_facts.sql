CREATE TEMP TABLE selected AS
SELECT channel_key, TO_HEX(SHA256(LOWER(country))) country_key,
 TO_HEX(SHA256(TO_JSON_STRING(STRUCT(LOWER(category) AS category, LOWER(channel_type) AS channel_type)))) category_key,
 snapshot_date, rank AS overall_rank, subscribers, video_views, uploads,
 subscribers_last_30_days, video_views_last_30_days, lowest_monthly_earnings,
 highest_monthly_earnings, lowest_yearly_earnings, highest_yearly_earnings,
 SAFE_DIVIDE(video_views, NULLIF(subscribers,0)) views_per_subscriber,
 SAFE_DIVIDE(video_views,NULLIF(uploads,0)) avg_views_per_upload, run_id
FROM `{{ params.project }}.silver.stg_channel` WHERE snapshot_date=@snapshot_date;
ASSERT NOT EXISTS (
 SELECT 1 FROM selected f
 LEFT JOIN `{{ params.project }}.gold.dim_channel` ch USING(channel_key)
 LEFT JOIN `{{ params.project }}.gold.dim_country` c USING(country_key)
 LEFT JOIN `{{ params.project }}.gold.dim_category` cat USING(category_key)
 LEFT JOIN `{{ params.project }}.gold.dim_date` d ON d.date_key=f.snapshot_date
 WHERE ch.channel_key IS NULL OR c.country_key IS NULL OR cat.category_key IS NULL OR d.date_key IS NULL
) AS 'Unresolved fact foreign keys';
ASSERT (SELECT COUNT(*) FROM selected)=@expected_rows AS 'Fact row loss';
CREATE TABLE IF NOT EXISTS `{{ params.project }}.gold.fact_channel_metrics`
PARTITION BY snapshot_date CLUSTER BY channel_key, country_key AS SELECT * FROM selected WHERE FALSE;
BEGIN TRANSACTION;
DELETE FROM `{{ params.project }}.gold.fact_channel_metrics` WHERE snapshot_date=@snapshot_date;
INSERT INTO `{{ params.project }}.gold.fact_channel_metrics` SELECT * FROM selected;
MERGE `{{ params.project }}.ops.pipeline_snapshot` t
USING (SELECT @snapshot_date snapshot_date, @checksum source_checksum, CURRENT_TIMESTAMP() updated_at) s
ON t.snapshot_date=s.snapshot_date
WHEN MATCHED THEN UPDATE SET source_checksum=s.source_checksum, updated_at=s.updated_at
WHEN NOT MATCHED THEN INSERT ROW;
COMMIT TRANSACTION;
