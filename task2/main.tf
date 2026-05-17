# task2/main.tf

# 1. Create a dedicated GCP Secret Manager secret for the tenant
resource "google_secret_manager_secret" "tenant_db_credentials" {
  secret_id = "tenant-${var.tenant_name}-credentials"
  project   = var.project_id

  replication {
    auto {}
  }
}

# Add a secret version with the credentials payload
resource "google_secret_manager_secret_version" "tenant_db_credentials_version" {
  secret      = google_secret_manager_secret.tenant_db_credentials.id
  secret_data = var.db_credentials
}

# 2. Create a dedicated GCP Service Account for the tenant's workload identity
resource "google_service_account" "tenant_workload_sa" {
  account_id   = "sa-${var.tenant_name}"
  display_name = "Workload Identity SA for ${var.tenant_name}"
  project      = var.project_id
}

# 3. Bind the Kubernetes SA to the GCP SA (Workload Identity)
resource "google_service_account_iam_binding" "workload_identity_binding" {
  service_account_id = google_service_account.tenant_workload_sa.name
  role               = "roles/iam.workloadIdentityUser"
  members = [
    "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_sa_name}]"
  ]
}

# 4. Scope the GCP SA access to *only* this specific secret (not project-wide)
resource "google_secret_manager_secret_iam_binding" "tenant_secret_accessor" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.tenant_db_credentials.secret_id
  role      = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${google_service_account.tenant_workload_sa.email}",
  ]
}
