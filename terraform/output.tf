output "bucket_name" {
  value       = google_storage_bucket.raw_landing.name
  description = "GCS bucket for raw landing zone."
}

output "bronze_dataset" {
  value       = google_bigquery_dataset.bronze.dataset_id
  description = "BigQuery bronze dataset."
}

output "silver_dataset" {
  value       = google_bigquery_dataset.silver.dataset_id
  description = "BigQuery silver dataset."
}

output "gold_dataset" {
  value       = google_bigquery_dataset.gold.dataset_id
  description = "BigQuery gold dataset."
}
