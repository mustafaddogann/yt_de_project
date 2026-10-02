# Design decisions

See ADRs for retained GCP, snapshot/history semantics, incremental partition publication, Type 1 channel modeling and separate synthetic governance. The source is small, but correctness still requires a defined grain and recovery behavior. A single CSV contract and bounded control row solve the actual problem without a generic framework.

Date partition filters limit transformation inputs. Clustering helps future larger histories but no measured savings are claimed. Bronze source strings preserve input formatting and prevent type autodetection changes. Silver performs safe conversion after strict source checks. Original bytes stay in immutable-path GCS objects; mutable dataset IAM does not constitute a compliance-certified immutable warehouse.

Marts are small latest-snapshot aggregations; full refresh remains appropriate. Script-level metrics may be incomplete and replacement writes are not described as exact business change counts. BigQuery dry run and offline syntax checks cannot replace cloud execution tests, IAM negative tests or identity reconciliation. Service separation uses scoped identities but both can be impersonated by a common scheduler; no worker isolation claim.
