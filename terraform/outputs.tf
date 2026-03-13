output "load_balancer_ip" {
  description = "IP address of the load balancer"
  value       = google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address
}

output "load_balancer_url" {
  description = "URL to access the application"
  value       = "http://${google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address}"
}

output "instance_group_name" {
  description = "Name of the managed instance group"
  value       = google_compute_region_instance_group_manager.uptime_mig.name
}

output "backend_service_name" {
  description = "Name of the backend service"
  value       = google_compute_backend_service.uptime_backend.name
}

output "health_check_name" {
  description = "Name of the health check"
  value       = google_compute_health_check.uptime_health_check.name
}

output "next_steps" {
  description = "Next steps to access and test the application"
  value       = <<-EOF
    
    Infrastructure deployed!
    
    Load Balancer: http://${google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address}
    
    Next steps:
       1. Wait 2-3 minutes for instances to become healthy
       
       2. Check health:
          gcloud compute backend-services get-health ${google_compute_backend_service.uptime_backend.name} --global
       
       3. Test it:
          curl http://${google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address}
       
       4. Monitor instances:
          cd ../scripts && ./monitor-instances.sh ${google_compute_global_forwarding_rule.uptime_forwarding_rule.ip_address}
    
    Ready to break things!
  EOF
}
