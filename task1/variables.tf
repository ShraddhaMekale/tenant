variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "tenant_name" {
  description = "Name of the tenant (e.g., acme-corp)"
  type        = string
}

variable "cloudsql_instance_name" {
  description = "Name of the existing Cloud SQL instance"
  type        = string
}

variable "db_password" {
  description = "Password for the tenant database user"
  type        = string
  sensitive   = true
}
