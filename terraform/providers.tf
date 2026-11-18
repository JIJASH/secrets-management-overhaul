terraform {
  required_version = ">= 1.5.0"

  required_providers {
    infisical = {
      source  = "Infisical/infisical"
      version = "~> 0.15.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6.0"
    }
  }
}

variable "org_id" {
  description = "Infisical Organization ID (injected via TF_VAR_org_id from SOPS)"
  type        = string
  sensitive   = true
}

variable "infisical_client_id" {
  description = "Universal Auth Client ID for Terraform Admin Identity"
  type        = string
  sensitive   = true
}

variable "infisical_client_secret" {
  description = "Universal Auth Client Secret for Terraform Admin Identity"
  type        = string
  sensitive   = true
}

provider "infisical" {
  host = "http://localhost:8080"

  auth = {
    universal = {
      client_id     = var.infisical_client_id
      client_secret = var.infisical_client_secret
    }
  }
}

