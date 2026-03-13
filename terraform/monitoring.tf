# Uptime monitoring check
resource "google_monitoring_uptime_check_config" "uptime_check" {
  display_name = "uptime-demo-check"
  timeout      = "10s"
  period       = "60s"

  http_check {
    path           = "/health"
    port           = 80
    request_method = "GET"
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address
    }
  }

  content_matchers {
    content = "healthy"
    matcher = "CONTAINS_STRING"
  }
}

# Alert policy for uptime failures  
resource "google_monitoring_alert_policy" "uptime_alert" {
  display_name = "uptime-demo-alert"
  combiner     = "OR"

  conditions {
    display_name = "Uptime check failure"

    condition_threshold {
      filter          = "metric.type=\"monitoring.googleapis.com/uptime_check/check_passed\" AND resource.type=\"uptime_url\" AND metric.label.check_id=\"${google_monitoring_uptime_check_config.uptime_check.uptime_check_id}\""
      duration        = "60s"
      comparison      = "COMPARISON_LT"
      threshold_value = 1

      aggregations {
        alignment_period   = "60s"
        per_series_aligner = "ALIGN_FRACTION_TRUE"
      }
    }
  }

  notification_channels = []

  alert_strategy {
    auto_close = "1800s"
  }
}
