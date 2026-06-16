variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "region" {
  description = "GCP region for the GCS bucket"
  type        = string
  default     = "US"
}

variable "bq_location" {
  description = "BigQuery dataset location (US or EU multi-region keeps free-tier scope wide)"
  type        = string
  default     = "US"
}

variable "bucket_name" {
  description = "GCS bucket name for the raw landing zone. Must be globally unique."
  type        = string
}
