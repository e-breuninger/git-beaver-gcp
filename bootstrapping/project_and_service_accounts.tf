# project
resource "google_project" "project" {
  name       = "breuninger-core-gitbeaver"
  project_id = "breuninger-core-gitbeaver"
  folder_id  = 0 // ID of parent folder for created project goes here
  billing_account = "000000-000000-000000" // ID of billing account goes here
}

# enable api
resource "google_project_service" "secretmanager-api" {
  project = google_project.project.project_id
  service = "secretmanager.googleapis.com"
}

# enable api
resource "google_project_service" "iam-api" {
  project = google_project.project.project_id
  service = "iam.googleapis.com"
}

# enable api
resource "google_project_service" "run-api" {
  project = google_project.project.project_id
  service = "run.googleapis.com"
}

# service account used in CI/CD
resource "google_service_account" "gitbeaver-cicd-sa" {
  project = google_project.project.project_id
  account_id   = "gitbeaver-cicd-sa"
  display_name = "GitBeaver CI/CD Service Account"
}

# access for CI/CD to access tf state bucket and write docker image to gcr repository
resource "google_project_iam_member" "service-account-member-cicd-1" {
  project = google_project.project.project_id
  role    = "roles/storage.admin"
  member  = "serviceAccount:${google_service_account.gitbeaver-cicd-sa.email}"
}

# allow CI/CD to create secret
resource "google_project_iam_member" "service-account-member-cicd-2" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.admin"
  member  = "serviceAccount:${google_service_account.gitbeaver-cicd-sa.email}"
}

# service account to run git beaver
resource "google_service_account" "gitbeaver-run-sa" {
  project = google_project.project.project_id
  account_id   = "gitbeaver-run-sa"
  display_name = "GitBeaver CloudRun Service Account"
}

# allow git beaver to read secret
resource "google_project_iam_member" "service-account-binding-gitbeaver-accessor" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.gitbeaver-run-sa.email}"
}

# allow git beaver to create new secret version
resource "google_project_iam_member" "service-account-binding-gitbeaver-adder" {
  project = google_project.project.project_id
  role    = "roles/secretmanager.secretVersionAdder"
  member  = "serviceAccount:${google_service_account.gitbeaver-run-sa.email}"
}

# bucket to store terraform state
resource "google_storage_bucket" "terraform_state" {
  name          = "gitbeaver-terraform-state"
  project = google_project.project.project_id
  force_destroy = false
  location      = "europe-west3"
  storage_class = "STANDARD"
  versioning {
    enabled = true
  }
}
