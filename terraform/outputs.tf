output "app_external_ip" {
  value = "${google_compute_instance.app.0.network_interface.0.access_config.0.assigned_nat_ip}"
}
output "app_external_ip2" {
  value = "${google_compute_instance.app.1.network_interface.0.access_config.0.assigned_nat_ip}"
}

output "balance_ip" {
value = "${google_compute_global_address.app_ip.address}"
}
