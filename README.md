# rastamalik_infra
##Homework 10
1. Создал файл ```inventory.yml``` с содержимым: 
```app: 
 hosts: 
  appserver:
   ansible_host: 35.205.71.79 
db: 
 hosts: 
  dbserver: 
   ansible_host: 35.195.224.187 
```
2.Создал файл ```inventory.json``` с содержимым: 
```{ 
"app": { 
  "hosts": { 
     "appserver": {  
"ansible_host": "35.205.71.79" 
} 
} 
}, 
"db": { 
 "hosts": {  
 "dbserver": {  
"ansible_host": "35.195.224.187" 
} 
} 
},
}  
3. Вывод команды **ansible all -m ping -i inventory.yml и inventory.json** 
```appserver | SUCCESS => { 
    "changed": false,  
    "ping": "pong" 
} 
dbserver | SUCCESS => { 
    "changed": false, 
    "ping": "pong" 
} 
```
## HOMEWORK 09
1. Задание выполено в директории **terraform** 
* Для создания инстансов **db** и **app**, *packer*-ом было создано два образа ***reddit-db-base*** и ***reddit-app-base*** и   объявили их в ```variables.tf```.
* После чего создали ```app.tf, db.tf, vpc.tf```.
2. Создаем модули, директорию **modules** и директории ***app, db, vpc***
* В подпапку **app** копируем код ```app.tf -> main.tf```, файлы ```outputs.tf, variables.tf``` 
* В подпапку **db** копируем код ```db.tf -> main.tf```, файлы ```outputs.tf, variables.tf``` 
* В папке **terraform** оставляем ```main.tf``` c ссылками на модули 
* В подпапке **vpc** создаем ```main.tf``` c настройками файервола 
3. В директории **terraform** создадим две директории **stage** и **prod** в которые перенесем файлы из **terraform** -  ```main.tf```, ```variables.tf```, ```outputs.tf```, ```terraform.tvfars```.
* В **stage** мы откроем доступ по SSH всем, в **prod** только для своего IP 
4. В папке **prod** создадим файл ```backend.tf``` c содержимым:
 ```terraform { 
 backend "gcs" { 
 bucket = "tf-prod" 
 prefix = "terraform/state"
 project ="clever-overview-188908" 
 region ="europe-west1"
 } 
 }
```
* В папке **stage** создадим файл ```backend.tf``` c содержимым:
```terraform { 
backend "gcs" { 
bucket = "tf-stage" 
prefix = "terraform/state" 
project ="clever-overview-188908" 
region ="europe-west1" 
} 
} 
```

* Этим мы создали удаленное хранение стейт файла на ***GCS***. 
* Создадим папки **prod2** и **stage2** и скопируем туда содержимое **prod** и **stage** только без стейт файла. 
* При применении конфигурации **terraform** из папок **prod2** и **stage2** стейт файл "видит" c ***GCS*** 

6. Добавление ```provisioner``` в модули **app** и **db**. 
* Для начала создали ***packer*** -ом образ **reddit-base образ** с чистой Ubuntu без приложения и бд, 
* В файле ```variables.tf``` в папке **stage2** поменяли переменную в  ```_disk_image``` на ***reddit-base*** 
* В файл ```main.tf``` в модули ```bd``` и ```app``` добавили ключ ```private_key = "${var.private_key}"```
* В папку **modules/app** добавили файлы для деплоя ***Puma - deploy.sh, puma.service*** а в файл ```main.tf``` добавим секцию: 
 ```connection { 
    type        = "ssh" 
    user        = "appuser" 
    agent       = false 
    private_key = "${file(var.private_key)}" 
  } 
  provisioner "file" { 
    source      = "../modules/app/puma.service" 
    destination = "/tmp/puma.service" 
  } 
  provisioner "remote-exec" { 
    script = "../modules/app/deploy.sh" 
  } 
  ```
* В папку **modules/db** добавил файл ***install_mongodb.sh*** для установки БД:
* В файл ```main.tf``` добавил секцию: 

```connection { 
    type        = "ssh" 
    user        = "appuser" 
    agent       = false 
    private_key = "${file(var.private_key)}" 
  } 

  provisioner "remote-exec" { 
    script = "../modules/db/install_mongodb.sh" 
  } 
```
7. Реестр модулей. 
В папке **terraform** создал файл ```storage-bucket.tf``` c содержимым:

```provider "google" { 
version = "1.4.0" 
project = "${var.project}" 
region = "${var.region}" 
} 

module "storage-bucket" { 
source = "SweetOps/storage-bucket/google" 
version = "0.1.1" 
name = ["storage-bucket-test3", "storage-bucket-test4"] 
} 

output storage-bucket_url { 
value = "${module.storage-bucket.url}" 
} 
```
* После применения конфигурации на выходе получил бакеты: 
```Outputs: 
storage-bucket_url = [ 
    gs://storage-bucket- test3, 
    gs://storage-bucket-test4 
] 
```
## Задание 8. 

1.Созданы файлы ```main.tf```, ```outputs.tf```,```variables.tf```,```terraform.tvfars.example```
2. Задание со звездочкой:
В ```metadata``` добавил
```ssh-keys = "appuser1:${var.ssh_rsa} appuser1"
ssh-keys = "appuser2:${var.ssh_rsa} appuser2"
```
3. Задание сдвумя звездочками:
Создал **HTTP балансер**, но **PUMA** пришлось запускать с портом 1883, который прописал **puma.service**,
т.к. в resource "global_forwarding_rule" опция ```port_range``` жескто прописывается с определенными портами. 

```resource "google_compute_global_address" "app_ip" {
name ="lb-ip-1"
} 

resource "google_compute_instance_group" "pumaservers" {
name = "puma-group"
description = "Terraform instance group" 

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

timeout_sec = 1
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
name = "default-backend"
protocol = "TCP"
timeout_sec = 10 

backend {
group = "${google_compute_instance_group.pumaservers.self_link}"
}
health_checks = ["${google_compute_health_check.default.self_link}"]
} 

resource "google_compute_global_forwarding_rule" "default" {
name = "default"
target = "${google_compute_target_tcp_proxy.default.self_link}"
ip_address = "https://www.googleapis.com/compute/v1/projects/clever-overview-188908/global/addresses/lb-ip-1"
port_range = "1883"
} 
```

## Homework 07. 
1.Создал ветку **packer-base** 
2.Создал директорию **config-scripts**, перенес скрипты с прошлого ДЗ.
3.Создал директорию **packer**, в нее уложил все ```*.json``` файлы. 
4.Для создания **reddit-base** образа, использовал ```ubuntu16.json```  
```$ packer build ubuntu16.json
```
5.Параметризировал шаблон ```ubuntu16.json```, все переменные описал в файле ```variables.json```, и создал образ командой 
```$ packer build -var-file=variables.json ubuntu16.json
```
6.Для "запекания" образа все в одном **reddit-full**, с запущенным приложением создал шаблон ```immutable.json``` 
```$ packer build immutable.json 
```
7.Для разворачивания VM машины использовал команду **gcloud**: 
```gcloud compute instances create reddit-full 
--boot-disk-size=20GB 
--image-family reddit-full 
--machine-type=g1-small 
--tags puma-server 
--restart-on-failure 
--zone=europe-west1-d 
```
8.Для автоматизации создания **VM** машин создал скрипт ```create-reddit-vm.sh```: 
```#!/bin/bash 
instance=$1 
gcloud compute instances create $1 
--boot-disk-size=20GB 
--image-family reddit-full 
--machine-type=g1-small 
--tags puma-server 
--restart-on-failure 
--zone=europe-west1-d 
```
9.Параметризировал шаблон ```immutable.json```, все переменные описал в файле ```variables-im.json```, и создал образ командой 
  ```$ packer build -var-file=variables-im.json immutable.json 
```
## HOMEWORK-06
```gcloud compute instances create reddit-app2 \   
--boot-disk-size=10GB \
--image-family ubuntu-1604-lts \
--image-project=ubuntu-os-cloud \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--metadata startup-script='wget -O - https://gist.github.com/rastamalik/f46a2d70f49fc428f1e6c2e0bce279dc/raw/run_app.sh | bash'
```
## HOMEWORK-05

1.В файл ```~/.ssh/config``` добавил секции


```Host bastion
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
```
2.

```Host bastion:  внешний IP-104.155.69.135, внутренний IP-10.132.0.2;```
```Host someinternalhost: внутренний IP-10.132.0.3;```

