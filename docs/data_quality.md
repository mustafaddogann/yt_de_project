# Data quality and source contract

contracts/youtube.json names all expected normalized columns, encoding, required values, provisional business key, row bounds and nonnegative metrics. Missing or unexpected columns and normalized name collisions fail validation. Structural CSV errors fail rather than shifting fields silently. Required blank values, duplicate keys, incompatible counts, negative metrics and nonfinite numbers are persisted to ops.rejected_record with reasons. Any rejects are a HARD gate: no partial accepted-only publication.

Source failures and transform failures create ops.data_quality_result records. SQL asserts selected-row reconciliation and every fact dimension relationship before fact partition publication. HARD failures stop downstream tasks; WARNING records provide delivery/reconciliation context without failing the run. Reject counts plus accepted counts reconcile to source count. This project stops on duplicate records rather than arbitrarily choosing a winner for business publication.

Schema evolution policy: missing, renamed, added or type-incompatible columns require contract review and tests. Optional missing values in existing nullable columns are accepted. New nullable columns are not accepted automatically. Deliberately update contract, explicit Bronze schema and transformations together, test in DEV, then approve deployment. There is no silent schema update option on load jobs.

Source count bounds are conservative contract bounds, not learned anomaly thresholds. Public channel information is not falsely classified as confidential. Security examples use separate fake contacts only.
