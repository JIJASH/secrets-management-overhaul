# 1. Create the main Infisical Project
# By default, Infisical automatically provisions 'dev', 'staging', and 'prod' environments inside a new project.
resource "infisical_project" "main" {
  name        = "secret-mgmt-overhaul"
  slug        = "secret-mgmt-overhaul"
  description = "Centralized secrets vault managed via Terraform IaC"
}

# 2. Define our target environments and logical secret folders
locals {
  environments = toset(["dev", "staging", "prod"])
  folders      = toset(["database", "storage", "registry", "ci-cd"])

  # Create a Cartesian product map of every environment + folder combination
  # e.g., "prod-database" => { env = "prod", folder = "database" }
  env_folders = {
    for pair in setproduct(local.environments, local.folders) :
    "${pair[0]}-${pair[1]}" => {
      env    = pair[0]
      folder = pair[1]
    }
  }
}

# 3. Create the folders inside every environment using a single resource block
resource "infisical_secret_folder" "app_folders" {
  for_each = local.env_folders

  project_id       = infisical_project.main.id
  environment_slug = each.value.env
  folder_path      = "/"
  name             = each.value.folder
}

# 4. Generate random passwords automatically (zero human-typed secrets)
resource "random_password" "db_password" {
  length           = 24
  special          = true
  override_special = "_-" # Safe characters for Postgres connection URLs
}

resource "random_password" "s3_secret_key" {
  length  = 32
  special = false
}

resource "random_password" "jwt_secret" {
  length  = 40
  special = false
}

resource "random_password" "registry_token" {
  length  = 32
  special = false
}

# 5. Inject the initial Production secrets directly into their Infisical folders
resource "infisical_secret" "prod_db_user" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/database"
  name         = "POSTGRES_USER"
  value        = "overhaul_app_user"

  depends_on = [infisical_secret_folder.app_folders]
}

resource "infisical_secret" "prod_db_password" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/database"
  name         = "POSTGRES_PASSWORD"
  value        = random_password.db_password.result

  depends_on = [infisical_secret_folder.app_folders]
}

resource "infisical_secret" "prod_db_name" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/database"
  name         = "POSTGRES_DB"
  value        = "overhaul_prod"

  depends_on = [infisical_secret_folder.app_folders]
}

resource "infisical_secret" "prod_s3_secret" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/storage"
  name         = "S3_SECRET_KEY"
  value        = random_password.s3_secret_key.result

  depends_on = [infisical_secret_folder.app_folders]
}

resource "infisical_secret" "prod_jwt_secret" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/storage"
  name         = "JWT_SIGNING_SECRET"
  value        = random_password.jwt_secret.result

  depends_on = [infisical_secret_folder.app_folders]
}

resource "infisical_secret" "prod_registry_token" {
  workspace_id = infisical_project.main.id
  env_slug     = "prod"
  folder_path  = "/registry"
  name         = "REGISTRY_AUTH_TOKEN"
  value        = "reg_live_${random_password.registry_token.result}"

  depends_on = [infisical_secret_folder.app_folders]
}

# 6. Output the created Project ID so we can inspect it
output "infisical_project_id" {
  description = "The ID of the provisioned Infisical workspace"
  value       = infisical_project.main.id
}
