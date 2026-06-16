# Landing zone for raw Kaggle CSVs before BigQuery ingestion.
resource "google_storage_bucket" "raw_landing" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = true
  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = 30
    }
    action {
      type = "Delete"
    }
  }
}

resource "google_bigquery_dataset" "bronze" {
  dataset_id  = "bronze"
  location    = var.bq_location
  description = "Raw landing zone tables loaded directly from GCS."
}

resource "google_bigquery_dataset" "silver" {
  dataset_id  = "silver"
  location    = var.bq_location
  description = "Typed, deduped, normalized staging tables."
}

resource "google_bigquery_dataset" "gold" {
  dataset_id  = "gold"
  location    = var.bq_location
  description = "Dimensional model and BI-ready marts."
}
