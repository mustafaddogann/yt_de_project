# Platform upgrade plan

## Current state
Inspected tracked Python, SQL, Terraform, Docker, documentation and CSV headers. Airflow 2.9.3 sends a local CSV through GCS to BigQuery. Bronze replaces a date partition; Silver and Gold replace all history. Source: 995 rows, 28 columns. No tests, CI or AGENTS.md.

## Problems
DAG import reads Variables and SQL. Autodetected types are unstable. The education column normalization differs from SQL. Source names are provisional keys; the static 2023 extract has no observation date. Unknown country/category keys do not resolve. Runtime permissions are broad. Landing retention deletes recovery evidence after 30 days. Legacy AWS code embeds a personal path.

## Target
Retain GCP architecture. Preserve original bytes in content addressed GCS objects. Bronze deduplicates delivery by date/checksum and retains attempts. Silver and facts replace only the selected snapshot in transactions. SHA256 dimension keys and unknown members resolve relationships. Channel uses Type 1 because source identity and history cannot substantiate SCD2. Facts retain historical country/category keys. Latest snapshot marts remain economical full refreshes. ops holds control, runs, steps and DQ. Synthetic contacts use a separate authorized masked view.

## Structure
DAG orchestrates modular utilities and SQL. contracts defines source expectations; tests and scripts validate offline; Terraform manages scoped identities; docs/adr explains tradeoffs.

## Sequence
Cleanup/test baseline; ops/auditing; Bronze/Silver history; dimensional model; DQ/rejects; synthetic governance/IAM; environment separation; CI/tests; monitoring/runbook; README.

## Risks and assumptions
Existing schemas require administrator backup/migration; do not destructively upgrade old cloud tables. Deploy first to a fresh DEV project. One DAG, max_active_runs=1; external writers unsupported. Source observation date must be supplied explicitly, not fabricated from execution time. Correcting an existing date requires explicit correction configuration. No cloud credentials here: cloud SQL/IAM/Docker smoke validation remains a deployment requirement.

## Acceptance
Cloud-free DAG import and tests; deterministic source identity; auditable failures; safe same-date retries; historical partitions preserved; hard DQ gates; resolved foreign keys; scoped IAM; runnable Docker setup; documented migration, recovery and validation limitations.
