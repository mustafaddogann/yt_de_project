# Operational runbook

| Incident | Response |
| :--- | :--- |
| Ingestion authentication failure | Inspect Airflow logs, step error, ADC expiry and impersonation grants; fix scope/auth, then clear failed task and downstream tasks |
| Bad/missing CSV | Inspect source_contract DQ and rejects; retain evidence; fix source or contract through review; rerun without fabricating observation date |
| Schema change | Stop publication, compare normalized headers to contract, update contract/schema/SQL together in DEV, test then deploy |
| Duplicate delivery | Verify date/checksum and counts; exact replay should skip Bronze and rebuild selected downstream snapshot |
| Changed delivery | Review correction justification, trigger with snapshot_date and allow_correction=true; preserve old checksum for rollback |
| DQ failure | Query DQ details and rejected records, correct the cause; do not disable hard checks to force green status |
| Partial pipeline failure | Find failed step in ops; Bronze remains; fix then clear failed and downstream tasks including finalize; preserve successful ingestion |
| Failed cloud load job | Inspect deterministic load job ID; successful ambiguous completion can be reattached; a confirmed terminal failed atomic load selects a deterministic recovery suffix on retry, capped at ten; never launch a second job while the first is still running |
| Failed transformation | Read BigQuery assertion and job error; transaction protects selected partition from partial DELETE/INSERT; fix then rerun |
| Incorrect deployment | Pause DAG, revert code commit, restore backed-up schema/data if schema changed, validate DEV, then resume |
| Historical backfill | Update control source_location to the historical file through reviewed change, trigger explicit historical date, serialize backfills, restore control afterward |
| Rerun | Same source date/checksum requires no correction flag; new Airflow run gets new audit identity; never relabel old source as a fresh observation |
| Rollback source correction | Select archived original source by checksum, stage it as configured input, rerun same date with allow_correction=true, verify DQ and latest marts |
| Cost increase | Inspect job IDs/bytes, selected partition predicates, query maximum_bytes_billed, retries and full mart scans; pause DAG if needed and review billing budgets |
| Missing final audit | Compare Airflow terminal states with ops; after ops recovery rerun finalize; audit availability cannot be guaranteed when BigQuery itself is down |

All correction/backfill examples require an actual source observation date. Do not delete archived source evidence during recovery. Fact transactions do not make the entire multi-table pipeline atomic; marts and dimensions can be from a different successful stage during PARTIAL runs. Consumers should inspect run freshness and successful completion before treating results as an approved release.
