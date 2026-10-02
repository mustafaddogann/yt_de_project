variable "project_id" {
  description = "Dedicated project per environment"
  type        = string
}
variable "region" {
  description = "Landing bucket location, compatible with BigQuery"
  type        = string
  default     = "US"
}
variable "bq_location" {
  type    = string
  default = "US"
}
variable "bucket_name" {
  type = string
}
variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "Environment must be dev or prod."
  }
}
variable "analyst_members" {
  description = "IAM principal strings; no real identities in committed configuration"
  type        = list(string)
  default     = []
}
variable "orchestrator_members" {
  description = "Principals permitted to impersonate runtime identities"
  type        = list(string)
  default     = []
}
variable "platform_admin_members" {
  description = "Deployment principals only; runtime identities excluded"
  type        = list(string)
  default     = []
}
