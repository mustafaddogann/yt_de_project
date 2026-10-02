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
