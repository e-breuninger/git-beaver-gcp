
# Secret for storing master key
resource "google_secret_manager_secret" "secret" {
  project = "${project_id}"
  secret_id = "gitbeaver-masterkey"

  replication {
    user_managed {
      replicas {
        location = "${location}"
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
  project = "${project_id}"
  account_id   = "gitbeaver-sa"
  display_name = "GitBeaver Service Account"
}

# allow accessing the secret
resource "google_project_iam_member" "service-account-binding-gitbeaver-accessor" {
  project = "${project_id}"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

# allow writing a new version of the secret
resource "google_project_iam_member" "service-account-binding-gitbeaver-adder" {
  project = "${project_id}"
  role    = "roles/secretmanager.secretVersionAdder"
  member  = "serviceAccount:${google_service_account.gitbeaver-sa.email}"
}

# cloud run service for git beaver
resource "google_cloud_run_service" "service" {
  project = "${project_id}"
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
        "autoscaling.knative.dev/minScale" = 0 // can scale down to save costs
        "autoscaling.knative.dev/maxScale" = 1 // must be 1, we do not want concurrent gitbeaver sessions
        # TODO: grant access to network to gitlab
        #"run.googleapis.com/vpc-access-connector" = "projects/breuninger-dataprocessing/locations/europe-west3/connectors/breuni-gitlab-cicd"
      }
    }
  }
  metadata {
    annotations = {
      "run.googleapis.com/ingress" = "all" // TODO: limit this to internal traffic?
    }
  }
  traffic {
    percent         = 100
    latest_revision = true
  }
}

# bucket to store the remote terraform state
terraform {
  backend "gcs" {
    bucket  = "breuni-gitbeaver-tfstate"
    prefix  = "core/gitbeaver"
  }
}