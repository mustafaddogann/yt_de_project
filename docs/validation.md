# Validation evidence

Validated in this execution workspace:

* 25 Python tests passed, covering the actual 995-row CSV, schema rejection, numeric rejection, duplicate detection, stable identity, source dates, audit propagation, load replay, failed-job recovery and correction authorization.
* Ruff lint and formatting passed.
* Python 3.11 syntax validation, JSON contract, Compose YAML and Terraform HCL parsing passed.
* SQLFluff parsed/linted all BigQuery scripts and monitoring SQL.
* Terraform 1.9.8 recursive formatting passed; provider initialization downloaded signed google 5.45.2.
* git diff whitespace validation passed.

GitHub CI additionally passed Terraform provider schema validation and the pinned Docker image build. The real DagBag import check reads the parsed in-memory DAG, avoiding an unnecessary metadata database lookup.

Not validated in the local workspace:

* Terraform validate cannot start the provider: listen unix socket operation not permitted in this environment. This is a runtime restriction, not a successful provider schema check.
* Docker build/start and real Airflow DagBag import could not run because Docker is unavailable. CI includes those checks with the pinned image.
* No GCP credentials were used. BigQuery execution, cloud rerun/backfill correctness, IAM denial checks and authorized-view access remain unverified. Execute the deployment smoke criteria in docs/deployment.md before calling the upgrade runnable in a cloud environment.

The source has no immutable channel ID or observation timestamp. Those data limitations remain regardless of passing static checks. Exact business inserted/updated counters and full child-job cost accounting are not implemented; reported layer counts and available job metrics are documented instead.
