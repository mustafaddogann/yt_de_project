# Deployment and migration

Use a separate GCP project per environment: dataset names remain bronze/silver/gold/ops and Terraform is not duplicated. Copy terraform/environments/dev.tfvars.example outside git and replace placeholders. Keep distinct backend state per project/environment. Never select PROD variables against DEV state.

Enable bigquery.googleapis.com, storage.googleapis.com, iam.googleapis.com, iamcredentials.googleapis.com and cloudresourcemanager.googleapis.com. Terraform provider authentication uses ADC or workload identity. Run terraform init, fmt -check, validate, plan and reviewed apply with your selected variable file. Terraform manages resources and IAM, while scripts/bootstrap.py creates operational/Bronze tables. Bootstrap never grants runtime administrator permissions.

After provisioning, install google-cloud-bigquery and jinja2 locally, export GCP_PROJECT_ID and BQ_LOCATION, run make bootstrap under deployment credentials. Configure .env and start make up. The ops control source path defaults to the Docker-mounted CSV. For synthetic demo seeding, render sql/bigquery/security_demo.sql with your project and execute as administrator. The sample is not automatically mixed into pipeline data.

## Existing installation

The old autodetected Bronze and replacement-built models are incompatible with the new schema and string keys. First deploy into a fresh DEV project. Export old tables and record their schemas/counts before any production cutover. CREATE TABLE IF NOT EXISTS does not migrate existing tables. For an existing project, stop the old DAG, retain/export data, create validated replacement datasets or deliberately recreate incompatible tables under administrator control, then switch the DAG. Replay only source snapshots whose observation dates are known. This upgrade never automatically drops old tables.

## Cloud smoke acceptance

1. Initialize a fresh DEV project, set strict impersonation identities and trigger a known source date.
2. Confirm SUCCEEDED run, 995 selected records in each layer, no rejects, and all DQ gates pass.
3. Trigger the same date/checksum as a new run. Bronze delivery count and Silver/fact business row counts must remain unchanged.
4. Load a distinct known observation date. Confirm both fact/Silver partitions remain and latest marts count only the newest.
5. Try an older-date backfill. Verify current channel/country attributes do not regress and later facts remain unchanged.
6. Try a changed same-date file without allow_correction; it must fail. Correct deliberately with allow_correction and verify stale rows are removed only for that date.
7. Supply bad schema/numbers/duplicates; confirm failure, persisted rejects where rows are parseable, and no downstream publication.
8. Force a downstream failure; confirm PARTIAL state, failed DAG and successful recovery after fixing and clearing failed tasks.
9. Query masked view using an analyst; base-table query must be denied. Try Gold writes as ingestion and GCS uploads as transformation; both must be denied.
10. Check query bytes, budget alerts and persisted raw objects; do not claim performance improvements without measurement.

No cloud deployment is included in static CI. A future deployment workflow should use GitHub OIDC and GCP workload identity federation with protected environment approvals; no long-lived keys. This repo supplies validation, not an untested automatic production deployment.
