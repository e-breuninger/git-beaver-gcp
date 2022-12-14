
variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "network" {
  type = string
}

variable "service_account" {
  type = string
}

variable "docker_image" {
  type = string
}

variable "run_git" {
  type = string
}

variable "run_repo" {
  type = string
}

variable "run_tag" {
  type = string
}

variable "run_script" {
  type = string
}


# Secret for storing master key
resource "google_secret_manager_secret" "secret" {
  project = var.project_id
  secret_id = "gitbeaver-masterkey"

  replication {
    user_managed {
      replicas {
        location = var.location
      }
    }
  }
}

# Initial dummy version of master key (the actual master key will not be terraformed to keep it out the tf-state)
resource "google_secret_manager_secret_version" "version" {
  secret = google_secret_manager_secret.secret.id
  secret_data = "not-set"
}

# cloud run service for git beaver
resource "google_cloud_run_service" "service" {
  project = var.project_id
  name     = "git-beaver"
  location = var.location
  template {
    spec {
      service_account_name = var.service_account
      containers {
        image = var.docker_image
        args = [
          join("=",["runGit", var.run_git]),
          join("=",["runRepo=", var.run_repo]),
          join("=",["runTag=", var.run_tag]),
          join("=",["runScript=", var.run_script])
        ]
        env {
          name = "gitbeaver-masterkey"
          value_from {
            secret_key_ref {
              key  = "latest"
              name = "gitbeaver-masterkey"
            }
          }
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale" = 0 // can scale down to save costs
        "autoscaling.knative.dev/maxScale" = 1 // must be 1, we do not want concurrent gitbeaver sessions
        // TODO "run.googleapis.com/vpc-access-connector" = var.network
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all" // TODO: limit to internal traffic?
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = [
      "allUsers",
    ]
  }
}

resource "google_cloud_run_service_iam_policy" "noauth" {
  location    = google_cloud_run_service.service.location
  project     = google_cloud_run_service.service.project
  service     = google_cloud_run_service.service.name

  policy_data = data.google_iam_policy.noauth.policy_data
}

terraform {
  backend "gcs" {
    bucket  = "gitbeaver-terraform-state"
    prefix  = "terraform/state"
  }
}