# Repository walkthrough without GCP

This walkthrough presents implemented definitions and illustrative behavior. It requires no cloud account. Tables below are explanatory fixtures, not captured execution results.

## Reading order

1. [Project plan](project_plan.md): scope, phases and all original requirements.
2. [Architecture](architecture.md): source through presentation plus the operational control plane.
3. [Data model](data_model.md): fact grain, keys, measures and historical semantics.
4. [Source contract](../contracts/youtube.json) and [validator](../dags/utils/utils.py): schema and rejection rules.
5. [Silver SQL](../sql/bigquery/silver_stg_channel.sql), [dimension SQL](../sql/bigquery/gold_dims.sql), [fact SQL](../sql/bigquery/gold_facts.sql): transformation implementation.
6. [Security](security.md) and [RBAC](rbac.md): masked view expression and granted access.
7. [Operations](operations.md), [monitoring](../sql/operations/monitoring.sql) and [runbook](runbook.md): ownership and recovery.

## Example: retained snapshots

The following fictional channel demonstrates the intended grain. Its dates are test fixtures, not observation dates asserted for the actual CSV.

| Channel | Snapshot date | Subscribers | Video views |
| :--- | :--- | ---: | ---: |
| Example Channel | 2023-08-01 | 100 | 1000 |
| Example Channel | 2023-09-01 | 120 | 1400 |

Bronze retains accepted source deliveries with their date/checksum and ingestion metadata. Silver and the fact retain both dates. The latest marts use only 2023-09-01. Repeating the August delivery must not add another August business row. Correcting August replaces only that partition; September remains intact. The checksum in ops.pipeline_snapshot identifies the currently published source for each date, separate from retained Bronze versions.

## Example: quality rejection

| Source issue | Defined action | Evidence object |
| :--- | :--- | :--- |
| Missing required header | Stop source validation | ops.data_quality_result |
| Missing channel name | Persist row/reason and stop downstream publication | ops.rejected_record |
| Negative subscribers | Persist invalid_numeric reason and stop | ops.rejected_record |
| Duplicate canonical channel name | Persist duplicate_business_key and stop | ops.rejected_record |
| Unresolved fact dimension | Abort before selected fact partition publication | Gold SQL ASSERT and failed step audit |
| Authorized historical correction | Record warning, retain old delivery, publish selected correction | ops.data_quality_result and ops.pipeline_snapshot |

## Example: masking

The seeded contact uses fake values. The view definition in Terraform is:

```sql
SELECT
  channel_key,
  'REDACTED' AS contact_name,
  CONCAT(SUBSTR(contact_email, 1, 1), '********@example.com') AS contact_email,
  'REDACTED' AS contact_phone
FROM `PROJECT.security_demo.synthetic_contacts`;
```

For mustafa@example.com the defined consumer email is m********@example.com. Base data is in security_demo; the consumer view is in masked_demo. Authorization connects that view to its restricted source. Analysts have consumer-view access and no defined base-table access. The SQL expression alone is not proof of enforcement; actual IAM denial requires later cloud execution.

## Example: operational ownership

| Question | Repository answer |
| :--- | :--- |
| Which file ran? | pipeline_run source_file/checksum and Bronze source URI |
| Where did it fail? | pipeline_step_run step_name, attempt, error and job ID |
| What data was rejected? | rejected_record JSON plus reasons; DQ outcome |
| Is the published version known? | pipeline_snapshot date/checksum pointer |
| How is an older date reprocessed? | Select historical source, pass explicit date, keep processing serial |
| Why does a warning not stop the DAG? | WARNING outcome is recorded; HARD rejection raises |
| What happens after a partial failure? | Preserve accepted Bronze; fix and clear failed/downstream tasks; rerun final audit |

## What can be verified without cloud access

Run make check after installing requirements-dev.txt. This exercises the real checked-in 995-row CSV and offline behavior. GitHub CI also validates Terraform, builds the pinned Docker image and imports the actual Airflow DAG. These checks establish code/configuration validation, not cloud processing or IAM enforcement.

## Accurate portfolio description

“I built a GCP data engineering reference project with a Medallion architecture, a dimensional snapshot model, metadata-driven control, process auditing, incremental partition processing, data quality gates, scoped IAM and a separate synthetic masking demonstration. The repository includes tested helpers, CI, Terraform definitions and recovery documentation. Cloud execution and access enforcement are a separate validation stage.”
