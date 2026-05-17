# task1/main.tf

# Create a dedicated PostgreSQL database for the tenant
resource "google_sql_database" "tenant_db" {
  name     = "${var.tenant_name}-db"
  instance = var.cloudsql_instance_name
  project  = var.project_id
}

# Create a dedicated PostgreSQL user for the tenant
resource "google_sql_user" "tenant_user" {
  name     = "${var.tenant_name}-user"
  instance = var.cloudsql_instance_name
  project  = var.project_id
  password = var.db_password
}
