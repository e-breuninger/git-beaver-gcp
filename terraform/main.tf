resource "google_project" "project" {
  name       = "breuni-infra-gitbeaver"
  project_id = "breuni-infra-gitbeaver"
  folder_id  = google_folder.folder.folder_id
  billing_account = "01C66F-E18B5A-ECE5D4"
}

resource "google_folder" "folder" {
  display_name = "infrastructure"
  parent       = "organizations/722026089310"
}

resource "google_project_service" "secretmanager-api" {
  project = google_project.project.project_id
  service = "secretmanager.googleapis.com"
}

resource "google_project_service" "run-api" {
  project = google_project.project.project_id
  service = "run.googleapis.com"
}

resource "google_secret_manager_secret" "secret" {
  project = google_project.project.project_id
  secret_id = "gitbeaver-masterkey"

  replication {
    user_managed {
      replicas {
        location = "europe-west3"
      }
    }
  }
}

resource "google_secret_manager_secret_version" "version" {
  secret = google_secret_manager_secret.secret.id
  secret_data = "not-set"
}

resource "google_service_account" "docker-repo-sa" {
  project = google_project.project.project_id
  account_id   = "docker-repo-sa"
  display_name = "DockerRepo Service Account"
}

resource "google_project_iam_member" "service-account-binding-docker" {
  project = google_project.project.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.docker-repo-sa.email}"
}

resource "google_service_account" "gitbeaver-sa" {
  project = google_project.project.project_id
  account_id   = "gitbeaver-sa"
  display_name = "GitBeaver Service Account"
}

resource "google_project_iam_member" "service-account-binding-gitbeaver-accessor" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

resource "google_project_iam_member" "service-account-binding-gitbeaver-adder" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.secretVersionAdder"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

resource "google_cloud_run_service" "service" {
  project = google_project.project.project_id
  name     = "git-beaver"
  location = "europe-west3"
  template {
    spec {
      service_account_name = google_service_account.gitbeaver-sa.account_id
      containers {
        image = "eu.gcr.io/breuni-infra-gitbeaver/gitbeaver:2022-11-11-07-38-17"
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
        "autoscaling.knative.dev/minScale" = 0
        "autoscaling.knative.dev/maxScale" = 1
        #"run.googleapis.com/vpc-access-connector" = "projects/breuninger-dataprocessing/locations/europe-west3/connectors/breuni-gitlab-cicd"
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all"
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

resource "google_storage_bucket" "terraform_state" {
  name          = "breuni-gitbeaver-tfstate"
  project = google_project.project.project_id
  force_destroy = false
  location      = "europe-west3"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}
terraform {
  backend "gcs" {
    bucket  = "breuni-gitbeaver-tfstate"
    prefix  = "terraform/state"
  }
}