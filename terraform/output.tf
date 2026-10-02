output "bucket_name" { value = google_storage_bucket.raw_landing.name }
output "bronze_dataset" { value = google_bigquery_dataset.bronze.dataset_id }
output "silver_dataset" { value = google_bigquery_dataset.silver.dataset_id }
output "gold_dataset" { value = google_bigquery_dataset.gold.dataset_id }
output "runtime_accounts" {
  value = { for key, account in google_service_account.runtime : key => account.email }
}
