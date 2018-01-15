terraform {
backend "gcs" {
bucket = "tf-prod"
prefix = "terraform/state"
project ="clever-overview-188908"
region ="europe-west1"
}
}
