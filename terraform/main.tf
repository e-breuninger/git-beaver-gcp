
variable "project_id" {
  type = string
}

variable "location" {
  type = string
}

variable "network" {
  type = string
}

variable "docker_image" {
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

# service aaccount under which the gitbeaver runs (not used for provisioning)
resource "google_service_account" "gitbeaver-sa" {
  project = var.project_id
  account_id   = "gitbeaver-sa"
  display_name = "GitBeaver Service Account"
}

# allow accessing the secret
resource "google_project_iam_member" "service-account-binding-gitbeaver-accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

# allow writing a new version of the secret
resource "google_project_iam_member" "service-account-binding-gitbeaver-adder" {
  project = var.project_id
  role    = "roles/secretmanager.secretVersionAdder"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

# cloud run service for git beaver
resource "google_cloud_run_service" "service" {
  project = var.project_id
  name     = "git-beaver"
  location = var.location
  template {
    spec {
      service_account_name = google_service_account.gitbeaver-sa.account_id
      containers {
        image = var.docker_image
        args = []
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
        "run.googleapis.com/vpc-access-connector" = var.network
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

terraform {
  backend "gcs" {
    bucket  = "gitbeaver-terraform-state"
    prefix  = "terraform/state"
  }
}