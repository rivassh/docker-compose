# =============================================================================
# Terraform Configuration – GitLab HTTP Backend for tfstate
# =============================================================================
# This Terraform configuration demonstrates:
#   - Using GitLab as a remote backend for tfstate (state locking)
#   - A simple resource definition (example: local file)
#
# Prerequisites:
#   - GitLab project with a Terraform state repository
#   - A GitLab Personal Access Token (scope: api, write_repository)
#   - Terraform >= 1.0.0 installed locally
#
# Setup:
#   1. Create a GitLab project to store tfstate (e.g., terraform-state)
#   2. Generate a GitLab Personal Access Token with 'api' and 'write_repository' scopes
#   3. Set the following environment variables:
#        export GITLAB_TOKEN="your-personal-access-token"
#        export GITLAB_PROJECT_ID="your-project-id" (found in project Settings > General)
#   4. Run: terraform init
#   5. Run: terraform plan
#   6. Run: terraform apply
# =============================================================================

terraform {
  # ── Configure GitLab as the remote backend ──
  backend "http" {
    # State file URL: GET to download, PUT to upload
    address = "https://gitlab.com/api/v4/projects/${var.gitlab_project_id}/terraform/state/${var.environment}"
    update_address = "https://gitlab.com/api/v4/projects/${var.gitlab_project_id}/terraform/state/${var.environment}"
    # Lock address: POST to acquire lock, DELETE to release
    lock_address = "https://gitlab.com/api/v4/projects/${var.gitlab_project_id}/terraform/state/${var.environment}/lock"
    unlock_address = "https://gitlab.com/api/v4/projects/${var.gitlab_project_id}/terraform/state/${var.environment}/lock"
    # HTTP headers for authentication
    lock_method = "POST"
    unlock_method = "DELETE"
    # Retry on server errors
    retry_min_wait = 4
    retry_max_wait = 12
  }

  required_providers {
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }

  required_version = ">= 1.0.0"
}

# ── Variables ──
variable "gitlab_project_id" {
  description = "GitLab project ID for storing Terraform state"
  type        = string
  sensitive   = true
}

variable "environment" {
  description = "Environment name (e.g., staging, production)"
  type        = string
  default     = "default"
}

variable "example_text" {
  description = "Example text to write to a file"
  type        = string
  default     = "Hello from Terraform + GitLab!"
}

variable "output_path" {
  description = "Path to the output file on the local machine"
  type        = string
  default     = "./output/terraform-demo.txt"
}

# ── Provider Configuration ──
# Note: We use the default / no-op provider for this demo.
# In a real project, you would configure your cloud provider here.

# ── Resources ──
resource "null_resource" "example" {
  triggers = {
    # Re-run when example_text changes
    text = var.example_text
  }

  provisioner "local-exec" {
    command = "echo '${var.example_text}' > ${var.output_path}"
  }
}

# ── Outputs ──
output "message" {
  description = "Message from the null resource"
  value       = "Terraform applied successfully. Check ${var.output_path} for output."
}

output "state_backend" {
  description = "State backend information"
  value       = "GitLab HTTP Backend (project ID: ${var.gitlab_project_id})"
}
