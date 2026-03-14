terraform {
  required_version = ">= 1.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Service account for instances
resource "google_service_account" "uptime_sa" {
  account_id   = "uptime-app-sa"
  display_name = "Uptime Demo Service Account"
  description  = "Service account for uptime demo instances"
}

# IAM roles for service account
resource "google_project_iam_member" "logging_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.uptime_sa.email}"
}

resource "google_project_iam_member" "monitoring_writer" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.uptime_sa.email}"
}

# Note: Cloud Armor removed - requires paid tier with quota

# Allow HTTP traffic from anywhere
resource "google_compute_firewall" "allow_http" {
  name    = "allow-http-uptime-demo"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["uptime-demo"]
}

# Allow health checks (these are GCP's health check IPs)
resource "google_compute_firewall" "allow_health_check" {
  name    = "allow-health-check-uptime-demo"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["80"]
  }

  # Google's health check IP ranges
  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = ["uptime-demo"]
}

# Instance template
resource "google_compute_instance_template" "uptime_template" {
  name_prefix  = "uptime-template-"
  machine_type = var.machine_type
  region       = var.region

  disk {
    source_image = "debian-cloud/debian-11"
    auto_delete  = true
    boot         = true
    disk_size_gb = 10
  }

  network_interface {
    network = "default"
    access_config {
      # Ephemeral public IP
    }
  }

  metadata = {
    startup-script = file("${path.module}/../scripts/startup-script.sh")
  }

  service_account {
    email  = google_service_account.uptime_sa.email
    scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring.write",
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  tags = ["uptime-demo"]

  lifecycle {
    create_before_destroy = true
  }

  labels = {
    purpose = "uptime-workshop"
  }
}

# Health check
resource "google_compute_health_check" "uptime_health_check" {
  name                = "uptime-health-check"
  check_interval_sec  = var.health_check_interval
  timeout_sec         = var.health_check_timeout
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  http_health_check {
    port         = 80
    request_path = "/health"
  }
}

# Regional managed instance group
resource "google_compute_region_instance_group_manager" "uptime_mig" {
  name               = "uptime-mig"
  base_instance_name = "uptime-instance"
  region             = var.region

  version {
    instance_template = google_compute_instance_template.uptime_template.id
  }

  target_size = var.instance_count

  named_port {
    name = "http"
    port = 80
  }

  auto_healing_policies {
    health_check      = google_compute_health_check.uptime_health_check.id
    initial_delay_sec = var.auto_healing_initial_delay
  }

  # Distribute instances across zones
  distribution_policy_zones = var.zones

  update_policy {
    type                  = "PROACTIVE"
    minimal_action        = "REPLACE"
    max_unavailable_fixed = 0
    max_surge_fixed       = 3
  }
}

# Backend service
resource "google_compute_backend_service" "uptime_backend" {
  name                  = "uptime-backend-service"
  protocol              = "HTTP"
  port_name             = "http"
  timeout_sec           = 10
  health_checks         = [google_compute_health_check.uptime_health_check.id]
  load_balancing_scheme = "EXTERNAL"

  backend {
    group           = google_compute_region_instance_group_manager.uptime_mig.instance_group
    balancing_mode  = "UTILIZATION"
    capacity_scaler = 1.0
  }

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# URL map
resource "google_compute_url_map" "uptime_url_map" {
  name            = "uptime-url-map"
  default_service = google_compute_backend_service.uptime_backend.id
}

# HTTP proxy
resource "google_compute_target_http_proxy" "uptime_http_proxy" {
  name    = "uptime-http-proxy"
  url_map = google_compute_url_map.uptime_url_map.id
}

# Global forwarding rule (load balancer frontend)
resource "google_compute_global_forwarding_rule" "uptime_forwarding_rule" {
  name                  = "uptime-forwarding-rule"
  target                = google_compute_target_http_proxy.uptime_http_proxy.id
  port_range            = "80"
  load_balancing_scheme = "EXTERNAL"
}
