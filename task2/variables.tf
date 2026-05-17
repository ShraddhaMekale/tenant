variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "tenant_name" {
  description = "Name of the tenant (e.g., acme-corp)"
  type        = string
}

variable "db_credentials" {
  description = "JSON string containing DB credentials"
  type        = string
  sensitive   = true
}

variable "k8s_namespace" {
  description = "The Kubernetes namespace of the tenant"
  type        = string
}

variable "k8s_sa_name" {
  description = "The Kubernetes ServiceAccount name of the tenant"
  type        = string
}
