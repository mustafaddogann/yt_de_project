-- Render params.project before use. Restrict time windows for growing audit history.
-- Ten recent runs.
SELECT run_id, snapshot_date, status, source_rows, silver_rows, gold_rows,
 TIMESTAMP_DIFF(ended_at, started_at, SECOND) duration_seconds
FROM `{{ params.project }}.ops.pipeline_run`
WHERE started_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
ORDER BY started_at DESC LIMIT 10;
-- Failures.
SELECT run_id, status, error_message FROM `{{ params.project }}.ops.pipeline_run`
WHERE started_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
 AND status IN ('FAILED','PARTIAL');
-- Duration and row volume.
SELECT DATE(started_at) execution_date, AVG(TIMESTAMP_DIFF(ended_at,started_at,SECOND)) average_seconds,
 SUM(source_rows) source_rows, SUM(rejected_rows) rejected_rows
FROM `{{ params.project }}.ops.pipeline_run`
WHERE started_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 30 DAY)
GROUP BY execution_date ORDER BY execution_date;
-- Freshness: source observation and successful pipeline execution are different clocks.
SELECT MAX(snapshot_date) latest_source_snapshot, MAX(ended_at) latest_successful_execution
FROM `{{ params.project }}.ops.pipeline_run` WHERE status='SUCCEEDED';
-- DQ failures and warnings.
SELECT run_id, check_name, severity, details, actual_value
FROM `{{ params.project }}.ops.data_quality_result`
WHERE checked_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 30 DAY) AND status='FAIL';
-- Snapshot volume changes.
SELECT snapshot_date, COUNT(*) channel_count,
 COUNT(*)-LAG(COUNT(*)) OVER (ORDER BY snapshot_date) change_since_prior_snapshot
FROM `{{ params.project }}.gold.fact_channel_metrics`
WHERE snapshot_date >= DATE_SUB(CURRENT_DATE(),INTERVAL 3650 DAY)
GROUP BY snapshot_date ORDER BY snapshot_date;
-- Available parent job metrics; script totals are not exact statement-level costs.
SELECT step_name, SUM(bytes_processed) reported_bytes, COUNT(*) attempts
FROM `{{ params.project }}.ops.pipeline_step_run`
WHERE started_at >= TIMESTAMP_SUB(CURRENT_TIMESTAMP(),INTERVAL 30 DAY)
GROUP BY step_name;
