terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "> 5.36.0"
    }
  }
}

locals {
 alias            = replace(replace(lower(var.name), " ", "-"), "_", "-")
 alias_short      = substr(local.alias, 0, 30)
}

provider "google" {
  project         = var.gcp_project_id
}

data "google_project" "project" {}

module "project_services" {
  source          = "terraform-google-modules/project-factory/google//modules/project_services"
  version         = "~> 17.0"

  project_id      = var.gcp_project_id
  enable_apis     = var.enable_apis

  activate_apis   = [
    "cloudbuild.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "run.googleapis.com",
    "storage-component.googleapis.com"
  ]
  disable_services_on_destroy = false
}

resource "google_service_account" "service_account" {
  project       = var.gcp_project_id
  account_id    = local.alias_short
  display_name  = var.name
}

resource "google_project_iam_member" "iam_project" {
  project       = var.gcp_project_id
  for_each      = toset([
    "roles/iam.serviceAccountUser",
    "roles/iam.serviceAccountTokenCreator",
    "roles/run.invoker",
    "roles/run.admin"
  ])
  role          = each.key
  member        = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_storage_bucket" "storage" {
  project       = var.gcp_project_id
  location      = var.gcp_region
  name          = "${var.gcp_project_id}-${local.alias_short}"
  uniform_bucket_level_access = true
}

resource "google_project_iam_member" "iam_storage" {
  project       = var.gcp_project_id
  role          = "roles/storage.objectAdmin"
  member        = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_secret_manager_secret" "secrets" {
  for_each      = var.notifiers
  project       = var.gcp_project_id
  secret_id     = "${local.alias}-${replace(each.key, "_" , "")}"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_iam_member" "iam_secrets" {
  for_each      = google_secret_manager_secret.secrets
  secret_id     = each.value.id
  role          = "roles/secretmanager.secretAccessor"
  member        = "serviceAccount:${google_service_account.service_account.email}"
}

resource "google_pubsub_topic" "topic" {
  project      = var.gcp_project_id
  name         = "cloud-builds"
}

resource "google_project_iam_member" "pubsub" {
  project = var.gcp_project_id
  role    = "roles/iam.serviceAccountTokenCreator"
  member  = "serviceAccount:service-${data.google_project.project.number}@gcp-sa-pubsub.iam.gserviceaccount.com"
}

# Google Chat

resource "google_secret_manager_secret_version" "googlechat_secret" {
  count         = var.notifiers.google_chat == null ? 0 : 1
  secret        = "projects/${data.google_project.project.number}/secrets/${local.alias}-googlechat"
  secret_data = var.notifiers.google_chat.webhook_url
}

resource "google_storage_bucket_object" "googlechat_config" {
  count         = var.notifiers.google_chat == null ? 0 : 1
  name          = "google-chat-notifier.yml"
  bucket        = google_storage_bucket.storage.name
  content       = <<EOF
apiVersion: cloud-build-notifiers/v1
kind: GoogleChatNotifier
metadata:
  name: ${local.alias}-googlechat
spec:
  notification:
    filter: build.status in [Build.Status.FAILURE, Build.Status.TIMEOUT, Build.Status.SUCCESS]
    delivery:
      webhookUrl:
        secretRef: webhook-url
  secrets:
  - name: webhook-url
    value: projects/${data.google_project.project.number}/secrets/${local.alias}-googlechat/versions/latest
EOF
}

resource "google_cloud_run_v2_service" "googlechat_service" {
  count         = var.notifiers.google_chat == null ? 0 : 1
  name          = "${local.alias}-googlechat"
  location      = var.gcp_region
  project       = var.gcp_project_id
  
  ingress       = "INGRESS_TRAFFIC_ALL"
  template {
    service_account = google_service_account.service_account.email
    containers {
      image     = "us-east1-docker.pkg.dev/gcb-release/cloud-build-notifiers/googlechat:latest"
      env {
        name    = "CONFIG_PATH"
        value   = "${google_storage_bucket.storage.url}/${google_storage_bucket_object.googlechat_config[0].output_name}"
      }
      env {
        name    = "PROJECT_ID"
        value   = var.gcp_project_id
      }
    }
  }
  depends_on = [ module.project_services, google_secret_manager_secret_version.googlechat_secret ]
  
}

resource "google_pubsub_subscription" "googlechat_subscription" {
  count         = var.notifiers.google_chat == null ? 0 : 1
  project       = var.gcp_project_id 
  name          = "${local.alias}-googlechat"
  topic         = google_pubsub_topic.topic.id
  expiration_policy {
    ttl = ""
  }
  push_config {
    oidc_token {
      service_account_email = google_service_account.service_account.email
    }
    push_endpoint = "${google_cloud_run_v2_service.googlechat_service[0].uri}"
  }
}

# Slack 

# TODO
