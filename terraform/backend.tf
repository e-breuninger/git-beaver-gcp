# bucket to store the remote terraform state
terraform {
  backend "gcs" {
    bucket  = "breuninger-terraform-remote-state"
    prefix  = "core/gitbeaver"
  }
}