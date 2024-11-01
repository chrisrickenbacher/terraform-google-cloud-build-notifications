variable "gcp_project_id" {
  type        = string
  description = "The ID of the GCP project where this template is to be deployed."
}

variable "gcp_region" {
  type        = string
  description = "The GCP region where this template is to be deployed."
}

variable "enable_apis" {
  type        = bool
  description = "Whether to automatically enable the necessary GCP APIs."
  default     = true
}

variable "name" {
  type        = string
  description = "Custom name used for the naming of all deplyoed ressources."
  default     = "Cloud Build Notifications"
}

variable "notifiers" {
  type = object({
    google_chat = object({
      webhook_url = string
    })
    # slack = object({
    # })
  })
  description = "Definition of the notifiers the Notifications are sent to."
  default = {}
}