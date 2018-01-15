provider "google" {
  version = "1.4.0"
  project = "${var.project}"
  region  = "${var.region}"

}


resource "google_compute_instance" "app" {
 count="2"
  name         = "reddit-app${count.index+1}"
  machine_type = "g1-small"
  zone         = "${var.zone}"
  boot_disk {
    initialize_params {
      image = "${var.disk_image}"
    }
  }

  metadata {
    sshKeys = "appuser:${file(var.public_key_path)} "
    ssh-keys = "appuser1:${var.ssh_rsa} appuser1"
    ssh-keys = "appuser2:${var.ssh_rsa} appuser2" 
    
 }
  tags = ["reddit-app${count.index+1}"]
  network_interface {
    network       = "default"
    access_config = {}
  }
  connection {
    type        = "ssh"
    user        = "appuser"
    agent       = false
    private_key = "${file(var.private_key)}"
  }
  provisioner "file" {
    source      = "files/puma.service"
    destination = "/tmp/puma.service"
  }
  provisioner "remote-exec" {
    script = "files/deploy.sh"
  }
}






resource "google_compute_firewall" "firewal_puma" {
  name    = "allow-puma-default"
  network = "default"

  allow {
    protocol = "tcp"
    ports    = ["1883"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["reddit-app1","reddit-app2"]
}

resource "google_compute_firewall" "firewall_ssh" {
name = "default-allow-ssh"
network = "default"

allow {
protocol = "tcp"
ports = ["22"]
}

source_ranges = ["0.0.0.0/0"]
}

resource "google_compute_global_address" "app_ip" {
 name ="lb-ip-1"

  }

resource "google_compute_instance_group" "pumaservers" {
  name        = "puma-group"
  description = "Terraform  instance group"

  instances = [
 "${google_compute_instance.app.0.self_link}",
   "${google_compute_instance.app.1.self_link}",    

 ]

 named_port {
    name = "http"
    port = "1883"
  }


  zone = "europe-west1-d"
}

resource "google_compute_health_check" "default" {
  name = "default"

  timeout_sec        = 1
  check_interval_sec = 1

  tcp_health_check {
    port = "1883"
  }
}


resource "google_compute_target_tcp_proxy" "default" {
  name = "default"
  description = "test"
  backend_service = "${google_compute_backend_service.default.self_link}"
}

resource "google_compute_backend_service" "default" {
  name        = "default-backend"
  protocol    = "TCP"
  timeout_sec = 10

backend {
    group = "${google_compute_instance_group.pumaservers.self_link}"
  }


  health_checks = ["${google_compute_health_check.default.self_link}"]
}

resource "google_compute_global_forwarding_rule" "default" {
  name        = "default"
target = "${google_compute_target_tcp_proxy.default.self_link}"
  ip_address  =  "https://www.googleapis.com/compute/v1/projects/clever-overview-188908/global/addresses/lb-ip-1"
  port_range  = "1883"
 
}
