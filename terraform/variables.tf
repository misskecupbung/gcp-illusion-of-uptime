variable "project_id" {
  description = "GCP Project ID"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "zones" {
  description = "List of zones for multi-zone deployment"
  type        = list(string)
  default     = ["us-central1-a", "us-central1-b", "us-central1-c"]
}

variable "instance_count" {
  description = "Number of instances in the managed instance group"
  type        = number
  default     = 3
}

variable "machine_type" {
  description = "Machine type for compute instances"
  type        = string
  default     = "e2-micro"
}

variable "health_check_interval" {
  description = "How often to check health (seconds)"
  type        = number
  default     = 5
}

variable "health_check_timeout" {
  description = "Max wait time for health check response (seconds)"
  type        = number
  default     = 5
}

variable "unhealthy_threshold" {
  description = "Failures before marking unhealthy"
  type        = number
  default     = 2
}

variable "healthy_threshold" {
  description = "Successes before marking healthy"
  type        = number
  default     = 2
}

variable "auto_healing_initial_delay" {
  description = "Wait before starting health checks (seconds)"
  type        = number
  default     = 60
}
