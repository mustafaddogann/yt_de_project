# Architecture

The platform retains Airflow LocalExecutor, GCS, BigQuery and Terraform. All cloud access occurs inside task functions. DAG parsing reads neither Airflow Variables nor SQL files. SQL renders at runtime from mounted files.

A manual run first registers itself and reads exactly one ops control row. The operator supplies snapshot_date. Validation precedes cloud loading. Original CSV bytes and normalized NDJSON are stored under raw/youtube/date/checksum. Conditional generation-zero uploads prevent overwriting deliveries. Ingestion loads the explicit Bronze schema from the normalized object.

Silver reads only the chosen date/checksum, deduplicates accepted channel keys and atomically replaces that date. Gold merges dimension dictionaries, validates selected facts and atomically replaces that fact date. Marts consume the latest available fact date. Audit finalization directly depends on every task with ALL_DONE and raises on pipeline failure, so failed upstream work cannot yield a green overall run.

This is one serial DAG, not a concurrent multi-writer platform. max_active_runs=1 is part of correctness. No cloud deployment has been performed by this repository change. Bootstrap is administrator-only and separate from runtime. The pipeline's GCS client and BigQuery clients both use the ingestion identity for landing/loading; transformations use the second identity.
