# rastamalik_infra
Задание 8.
1.Созданы файлы main.tf, outputs.tf,variables.tf,terraform.tvfars.example \
2. Задание со звездочкой: \
В metadata добавил  \
ssh-keys = "appuser1:${var.ssh_rsa} appuser1" \
ssh-keys = "appuser2:${var.ssh_rsa} appuser2" \
3. Задание сдвумя звездочками: \
Создал HTTP балансер, но PUMA пришлось запускать с портом 1883, который прописал puma.service, \
т.к. в resource "global_forwarding_rule" опция port_range жескто прописывается с определенными портами. \

resource "google_compute_global_address" "app_ip" { \
 name ="lb-ip-1" \
  } \

resource "google_compute_instance_group" "pumaservers" { \
  name        = "puma-group" \
  description = "Terraform  instance group" \

  instances = [ \
 "${google_compute_instance.app.0.self_link}", \
   "${google_compute_instance.app.1.self_link}", \
 ] \

 named_port { \
    name = "http" \
    port = "1883" \
  } \
  zone = "europe-west1-d" \
} \

resource "google_compute_health_check" "default" { \
  name = "default" \

  timeout_sec        = 1 \
  check_interval_sec = 1 \

  tcp_health_check { \
    port = "1883" \
  } \
} \

resource "google_compute_target_tcp_proxy" "default" { \
  name = "default" \
  description = "test" \
  backend_service = "${google_compute_backend_service.default.self_link}" \
} \

resource "google_compute_backend_service" "default" { \
  name        = "default-backend" \
  protocol    = "TCP" \
  timeout_sec = 10 \

backend { \
    group = "${google_compute_instance_group.pumaservers.self_link}" \
  } \
  health_checks = ["${google_compute_health_check.default.self_link}"] \
} \

resource "google_compute_global_forwarding_rule" "default" { \
  name        = "default" \
target = "${google_compute_target_tcp_proxy.default.self_link}" \
  ip_address  =  "https://www.googleapis.com/compute/v1/projects/clever-overview-188908/global/addresses/lb-ip-1" \
  port_range  = "1883" \
} \


Задание 1.
В файл ~/.ssh/config добавил секции


Host bastion
Hostname 104.155.69.135 
IdentityFile ~/.ssh/appuser
user appuser
ForwardAgent yes


Host someinternalhost
ForwardAgent yes
Hostname someinternalhost
IdentityFile ~/.ssh/appuser
user appuser
ProxyCommand ssh -W %h:%p bastion

Задание 2.

Host bastion:  внешний IP-104.155.69.135, внутренний IP-10.132.0.2;
Host someinternalhost: внутренний IP-10.132.0.3;

