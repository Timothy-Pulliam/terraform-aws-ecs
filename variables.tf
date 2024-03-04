variable "app_name" {
  type        = string
  description = "Name of Elastic Container Registry"
  default     = "myapp"
}

variable "region" {
  type        = string
  description = "AWS Region"
  default     = "us-east-1"
}

variable "docker_image_uri" {
  type        = string
  description = "Docker Image URI to be used"
}

variable "cloudwatch_skip_destroy" {
  type        = bool
  description = "Set to true if you do not wish the log group (and any logs it may contain) to be deleted at destroy time, and instead just remove the log group from the Terraform state."
  default     = true
}
