# GCP Cloud Build Notifications with Terraform

Terraform Module to set up Cloud Build notifications.

## Features

- Send Cloud Build notification (Success, Failure, Timeout) to Google Chat

## Example

```hcl
module "cloudbuild_notifications" {
  source         = "chrisrickenbacher/cloud-build-notifications/google"
  name           = "cloudbuild notifications" # optional
  gcp_project_id = var.project
  gcp_region     = var.main_region
  enable_apis    = true # optional
  notifiers = {
    google_chat = {
      webhook_url = "https://chat.googleapis.com/v1/spaces/...." # webhook url of space
    }
  }
}
```

