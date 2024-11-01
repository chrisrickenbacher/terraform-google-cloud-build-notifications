<div align="center">

# GCP Cloud Build Notifications with Terraform

Terraform Module to set up Cloud Build notifications.

<h3>

[Terraform Module Registry](https://registry.terraform.io/) | [Cloud Build notifiers doc from Google](https://cloud.google.com/build/docs/configuring-notifications/notifiers)

</h3>

</div>

## Features

- Send Cloud Build notification (Success, Failure, Timeout) to Google Chat

## How to use

```hcl
module "cloudbuild_notifications" {
  source = "chrisrickenbacher/cloud-build-notifications/google"
  gcp_project_id = ""
  gcp_region = ""
  enable_apis = true
  notifiers = {
    google_chat = {
      webhook_url = ""
    }
  }
}
```

