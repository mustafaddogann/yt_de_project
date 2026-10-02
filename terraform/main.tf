resource "google_storage_bucket" "raw_landing" {
  name                        = var.bucket_name
  location                    = var.region
  force_destroy               = false
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  labels                      = { environment = var.environment, application = "youtube" }
}
resource "google_bigquery_dataset" "bronze" {
  dataset_id = "bronze"
  location   = var.bq_location
  labels     = { environment = var.environment }
}
resource "google_bigquery_dataset" "silver" {
  dataset_id = "silver"
  location   = var.bq_location
  labels     = { environment = var.environment }
}
resource "google_bigquery_dataset" "gold" {
  dataset_id = "gold"
  location   = var.bq_location
  labels     = { environment = var.environment }
}
resource "google_bigquery_dataset" "ops" {
  dataset_id = "ops"
  location   = var.bq_location
}
resource "google_bigquery_dataset" "security_demo" {
  dataset_id = "security_demo"
  location   = var.bq_location
}
resource "google_bigquery_dataset" "masked_demo" {
  dataset_id = "masked_demo"
  location   = var.bq_location
}
resource "google_service_account" "runtime" {
  for_each     = toset(["ingestion", "transformation"])
  account_id   = "yt-${var.environment}-${each.key}"
  display_name = "YouTube ${each.key} runtime"
}
resource "google_project_iam_member" "runtime_jobs" {
  for_each = google_service_account.runtime
  project  = var.project_id
  role     = "roles/bigquery.jobUser"
  member   = "serviceAccount:${each.value.email}"
}
locals {
  dataset_grants = {
    ingestion_bronze = { dataset = "bronze", role = "roles/bigquery.dataEditor", persona = "ingestion" }
    ingestion_ops    = { dataset = "ops", role = "roles/bigquery.dataEditor", persona = "ingestion" }
    transform_raw    = { dataset = "bronze", role = "roles/bigquery.dataViewer", persona = "transformation" }
    transform_ops    = { dataset = "ops", role = "roles/bigquery.dataEditor", persona = "transformation" }
    transform_silver = { dataset = "silver", role = "roles/bigquery.dataEditor", persona = "transformation" }
    transform_gold   = { dataset = "gold", role = "roles/bigquery.dataEditor", persona = "transformation" }
  }
}
resource "google_bigquery_dataset_iam_member" "runtime" {
  for_each   = local.dataset_grants
  dataset_id = each.value.dataset
  role       = each.value.role
  member     = "serviceAccount:${google_service_account.runtime[each.value.persona].email}"
  depends_on = [google_bigquery_dataset.bronze, google_bigquery_dataset.silver, google_bigquery_dataset.gold, google_bigquery_dataset.ops]
}
resource "google_storage_bucket_iam_member" "landing_create" {
  bucket = google_storage_bucket.raw_landing.name
  role   = "roles/storage.objectCreator"
  member = "serviceAccount:${google_service_account.runtime["ingestion"].email}"
}
resource "google_storage_bucket_iam_member" "landing_read" {
  bucket = google_storage_bucket.raw_landing.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.runtime["ingestion"].email}"
}
resource "google_bigquery_table" "contacts" {
  dataset_id          = google_bigquery_dataset.security_demo.dataset_id
  table_id            = "synthetic_contacts"
  deletion_protection = true
  description         = "Synthetic Security Demonstration: fake contacts only"
  schema = jsonencode([
    { name = "channel_key", type = "STRING", mode = "REQUIRED" },
    { name = "contact_name", type = "STRING", mode = "NULLABLE" },
    { name = "contact_email", type = "STRING", mode = "NULLABLE" },
    { name = "contact_phone", type = "STRING", mode = "NULLABLE" }
  ])
}
resource "google_bigquery_table" "masked_contacts" {
  dataset_id          = google_bigquery_dataset.masked_demo.dataset_id
  table_id            = "masked_contacts"
  deletion_protection = true
  view {
    query          = "SELECT channel_key, 'REDACTED' AS contact_name, CONCAT(SUBSTR(contact_email, 1, 1), '********@example.com') AS contact_email, 'REDACTED' AS contact_phone FROM `${var.project_id}.security_demo.synthetic_contacts`"
    use_legacy_sql = false
  }
  depends_on = [google_bigquery_table.contacts]
}
# Do not combine IAM policy resources with dataset access resources on this dataset.
resource "google_bigquery_dataset_access" "authorized_view" {
  dataset_id = google_bigquery_dataset.security_demo.dataset_id
  view {
    project_id = var.project_id
    dataset_id = google_bigquery_table.masked_contacts.dataset_id
    table_id   = google_bigquery_table.masked_contacts.table_id
  }
}
resource "google_bigquery_dataset_iam_member" "analyst" {
  for_each   = { for pair in setproduct(var.analyst_members, ["gold", "masked_demo"]) : "${pair[0]}:${pair[1]}" => pair }
  dataset_id = each.value[1]
  role       = "roles/bigquery.dataViewer"
  member     = each.value[0]
  depends_on = [google_bigquery_dataset.gold, google_bigquery_dataset.masked_demo]
}
resource "google_project_iam_member" "analyst_jobs" {
  for_each = toset(var.analyst_members)
  project  = var.project_id
  role     = "roles/bigquery.jobUser"
  member   = each.value
}
resource "google_service_account_iam_member" "impersonation" {
  for_each           = { for pair in setproduct(var.orchestrator_members, ["ingestion", "transformation"]) : "${pair[0]}:${pair[1]}" => pair }
  service_account_id = google_service_account.runtime[each.value[1]].name
  role               = "roles/iam.serviceAccountTokenCreator"
  member             = each.value[0]
}
resource "google_project_iam_member" "platform_admin" {
  for_each = { for pair in setproduct(var.platform_admin_members, ["roles/bigquery.admin", "roles/storage.admin"]) : "${pair[0]}:${pair[1]}" => pair }
  project  = var.project_id
  role     = each.value[1]
  member   = each.value[0]
}
