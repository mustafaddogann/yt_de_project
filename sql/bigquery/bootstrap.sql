CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.pipeline_control` (
 pipeline_name STRING, source_name STRING, source_type STRING, source_location STRING,
 target_dataset STRING, target_table STRING, load_type STRING, load_frequency STRING,
 is_active BOOL, expected_schedule STRING, watermark_column STRING,
 data_quality_enabled BOOL, retention_days INT64, created_at TIMESTAMP, updated_at TIMESTAMP
);
MERGE `{{ params.project }}.ops.pipeline_control` t
USING (SELECT 'youtube_de_pipeline' pipeline_name) s ON t.pipeline_name=s.pipeline_name
WHEN NOT MATCHED THEN INSERT VALUES ('youtube_de_pipeline', 'kaggle_global_youtube_2023', 'CSV',
 '/opt/airflow/data/Global YouTube Statistics.csv', 'bronze', 'raw_youtube_stats',
 'SNAPSHOT', 'MANUAL', TRUE, 'manual source observation date', 'snapshot_date', TRUE, 3650,
 CURRENT_TIMESTAMP(), CURRENT_TIMESTAMP());
CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.pipeline_run` (
 run_id STRING, pipeline_name STRING, airflow_run_id STRING, snapshot_date DATE,
 started_at TIMESTAMP, ended_at TIMESTAMP, status STRING, source_file STRING,
 source_checksum STRING, source_rows INT64, bronze_rows INT64, silver_rows INT64,
 gold_rows INT64, rejected_rows INT64, error_message STRING
) PARTITION BY DATE(started_at) CLUSTER BY pipeline_name, status;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.pipeline_step_run` (
 run_id STRING, step_name STRING, attempt INT64, started_at TIMESTAMP, ended_at TIMESTAMP,
 status STRING, job_id STRING, bytes_processed INT64, affected_rows INT64, error_message STRING
) PARTITION BY DATE(started_at) CLUSTER BY run_id;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.data_quality_result` (
 run_id STRING, check_name STRING, table_name STRING, check_type STRING,
 expected_value STRING, actual_value STRING, status STRING, severity STRING,
 checked_at TIMESTAMP, details STRING
) PARTITION BY DATE(checked_at) CLUSTER BY run_id;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.rejected_record` (
 run_id STRING, snapshot_date DATE, row_number INT64, record_json STRING, reasons STRING
) PARTITION BY snapshot_date CLUSTER BY run_id;
CREATE TABLE IF NOT EXISTS `{{ params.project }}.bronze.raw_youtube_stats` (
  rank STRING,
  youtuber STRING,
  subscribers STRING,
  video_views STRING,
  category STRING,
  title STRING,
  uploads STRING,
  country STRING,
  abbreviation STRING,
  channel_type STRING,
  video_views_rank STRING,
  country_rank STRING,
  channel_type_rank STRING,
  video_views_for_the_last_30_days STRING,
  lowest_monthly_earnings STRING,
  highest_monthly_earnings STRING,
  lowest_yearly_earnings STRING,
  highest_yearly_earnings STRING,
  subscribers_for_last_30_days STRING,
  created_year STRING,
  created_month STRING,
  created_date STRING,
  gross_tertiary_education_enrollment STRING,
  population STRING,
  unemployment_rate STRING,
  urban_population STRING,
  latitude STRING,
  longitude STRING, channel_key STRING, run_id STRING, source_file STRING, source_system STRING,
  source_checksum STRING, ingestion_timestamp TIMESTAMP, snapshot_date DATE
) PARTITION BY snapshot_date CLUSTER BY source_checksum, channel_key;

CREATE TABLE IF NOT EXISTS `{{ params.project }}.ops.pipeline_snapshot` (
 snapshot_date DATE, source_checksum STRING, updated_at TIMESTAMP
) PARTITION BY snapshot_date;
