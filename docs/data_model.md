# Data model

| Table | Grain | Strategy |
| :--- | :--- | :--- |
| bronze.raw_youtube_stats | Accepted source row per snapshot/date/checksum delivery | Append once per delivery; explicit string source columns plus metadata |
| silver.stg_channel | Normalized channel name per snapshot date | Replace selected partition in transaction |
| gold.dim_channel | Normalized channel name | SHA256 provisional key, Type 1, latest snapshot wins |
| gold.dim_country | Normalized country name | SHA256, Type 1 attributes, latest observation wins |
| gold.dim_category | Normalized category and channel type | SHA256 JSON struct key, insert dictionary members |
| gold.dim_date | Source snapshot date | Add selected date |
| gold.fact_channel_metrics | Channel and source snapshot date | Atomic selected-date replacement |
| gold.mart_* | Latest snapshot analytical aggregation | Full refresh for small outputs |

Null country/category/type receive an explicit Unknown label, materialized into dictionaries when observed. Facts store the country/category keys from their own source snapshot; do not derive historical classification from the current dim_channel. Channel titles displayed on historical fact joins remain current Type 1 attributes. Country contextual attributes such as population are also Type 1, not historical country observations.

Stable SHA256 is durable for the canonical name, but a rename produces a new identity. Case variants collapse. Channel names are not immutable YouTube IDs. Migrate to real IDs with an explicit reconciliation mapping before adding SCD2. No invented SCD timeline is presented.

Counts/earnings use NUMERIC to preserve large scientific notation values. Silver environmental numeric fields use SAFE_CAST; optional blanks become null. Source contract validation is responsible for refusing nonblank incompatible input. Fact foreign keys are enforced by SQL assertions; BigQuery does not enforce foreign keys here.

## Key relationships and measure definitions

| Fact field | Dimension relationship | Definition |
| :--- | :--- | :--- |
| channel_key | dim_channel.channel_key | SHA256 of canonical source channel name |
| country_key | dim_country.country_key | SHA256 of normalized country; classification as observed in the fact snapshot |
| category_key | dim_category.category_key | SHA256 of structured normalized category/channel_type pair |
| snapshot_date | dim_date.date_key | Source observation date supplied by the operator |
| subscribers | Snapshot measure | Reported subscriber total, NUMERIC |
| video_views | Snapshot measure | Reported cumulative view total, NUMERIC |
| uploads | Snapshot measure | Reported upload total, NUMERIC |
| subscribers_last_30_days | Window measure | Source-reported subscriber window, not a locally reconstructed delta |
| video_views_last_30_days | Window measure | Source-reported view window |
| earnings range fields | Source estimates | Monthly/yearly low/high values; not verified revenue |
| views_per_subscriber | Derived ratio | video_views divided by subscribers; null for zero denominator |
| avg_views_per_upload | Derived ratio | video_views divided by uploads; null for zero denominator |
| run_id | Initial ingestion lineage | Source run identity retained from Bronze; transform attempts are in ops |

Cumulative snapshot measures are not additive across dates. Summing a channel's subscribers from successive snapshots double-counts the population. Compare snapshots or aggregate channels within a selected date. Latest marts intentionally select one latest fact date. Country/category ratios and totals inherit the source's coverage limitations; this is a top-channel extract, not a census of YouTube.

The star diagram, layer map and masking example are in [project_plan.md](project_plan.md). [project_walkthrough.md](project_walkthrough.md) shows illustrative snapshots and rejection behavior without claiming live execution.
