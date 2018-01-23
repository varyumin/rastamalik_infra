# rastamalik_infra
## Homework 11
1. Создаем  плейбук  с одним сценарием для Mongo **reddit_app.yml**:
```---
- name: Configure hosts & deploy application
  hosts: all
  vars:
    mongo_bind_ip: 0.0.0.0
   
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      tags: db-tag
      notify: restart mongod
```
Делаем проверку плейбука:
```ansible-playbook reddit_app.yml--check --limit db```

2. Добавим handlers для рестарта MongoDB:
``` handlers:
  - name: restart mongod
    become: true
    service: name=mongod state=restarted
```
3. Настройка инстанса приложения:
Добавим в **reddit_app.yml** сценарий для настройки Puma:
```---
- name: Configure hosts & deploy application
  hosts: all
  vars:
    mongo_bind_ip: 0.0.0.0
    db_host: 10.132.0.2 
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      tags: db-tag
      notify: restart mongod
    - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/appuser/db_config
      tags: app-tag

    - name: Add unit file for Puma
      become: true
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      tags: app-tag
      notify: reload puma
    - name: enable puma
      become: true
      systemd: name=puma enabled=yes
      tags: app-tag
handlers:
  - name: restart mongod
    become: true
    service: name=mongod state=restarted
  - name: reload puma
    become: true
    systemd: name=puma state=reloaded
  - name: restart puma
    become: true
```
Применим наши таски с тегом **app-tag**:

```ansible-playbook reddit_app.yml --limit app --tags app-tag```

3. Добавление сценария для деплоя с тегом **deploy-tag**:

```- name: Fetch the latest version of application code
      become: true
      git:
        repo: 'https://github.com/Otus-DevOps-2017-11/reddit.git'
        dest: /home/appuser/reddit
        version: monolith
      tags: deploy-tag
      notify: restart puma
    - name: Bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit
      tags: deploy-tag
```

4. Создадим плейбук и разобьем его на несколько сценариев:
```---
- name: Configure MongoDB
  hosts: db
  tags: db-tag
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      notify: restart mongod

  handlers:
  - name: restart mongod
    service: name=mongod state=restarted
- name: Configure App
  hosts: app
  tags: app-tag
  become: true
  vars:
   db_host: 10.132.0.2
  tasks:
    - name: Add unit file for Puma
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      notify: reload puma

    - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/appuser/db_config
        owner: appuser
        group: appuser

    - name: enable puma
      systemd: name=puma enabled=yes
  handlers:
  - name: reload puma
    systemd: name=puma state=reloaded


- name: Deploy app
  hosts: app
  tags: deploy-tag
  tasks:
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/Otus-DevOps-2017-11/reddit.git'
        dest: /home/appuser/reddit
        version: monolith
     
      notify: restart puma
    - name: Bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit

  handlers:
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
```
Для запуска сценариев используем теги **app-tag**,**db-tag**,**deploy-tag**
 
```ansible-playbook reddit_app_multiple_plays.yml --tags db-tag
ansible-playbook reddit_app_multiple_plays.yml --tags app-tag
ansible-playbook reddit_app_multiple_plays.yml --tags deploy-tag
```

5. Создадим несколько плейбуков **app.yml**,**db.yml**,**deploy.yml**
**app.yml**

```- name: Configure App
  hosts: app
  become: true
  vars:
   db_host: 10.132.0.3
  tasks:
    - name: Add unit file for Puma
      copy:
        src: files/puma.service
        dest: /etc/systemd/system/puma.service
      notify: reload puma

    - name: Add config for DB connection
      template:
        src: templates/db_config.j2
        dest: /home/appuser/db_config
        owner: appuser
        group: appuser

    - name: enable puma
      systemd: name=puma enabled=yes
  handlers:
  - name: reload puma
    systemd: name=puma state=reloaded
   ```
    
  **db.yml**
 ``` - name: Configure MongoDB
  hosts: db
  become: true
  vars:
    mongo_bind_ip: 0.0.0.0
  tasks:
    - name: Change mongo config file
      become: true
      template:
        src: templates/mongod.conf.j2
        dest: /etc/mongod.conf
        mode: 0644
      notify: restart mongod

  handlers:
  - name: restart mongod
    service: name=mongod state=restarted
 ```
 **deploy.yml**
```- name: Deploy app
  hosts: app
  tags: deploy-tag
  tasks:
    - name: Fetch the latest version of application code
      git:
        repo: 'https://github.com/Otus-DevOps-2017-11/reddit.git'
        dest: /home/appuser/reddit
        version: monolith

      notify: restart puma
    - name: Bundle install
      bundler:
        state: present
        chdir: /home/appuser/reddit

  handlers:
  - name: restart puma
    become: true
    systemd: name=puma state=restarted
  ```
  Создадим site.yml это будет нашим главным плейбуком который будет включать в себя остальные:
  
  ```- include: db.yml
- include: app.yml
- include: deploy.yml
  ```
  Для проверки наших плейбуков пересоздадим инфраструктуру окружения **stage**, и проверим работу плейбуков:
  
  ```ansible-playbook site.yml```
  Проверим работу приложения по внешнему адресу IP:9292
  
  6. Изменим _provision_ в **Packer** bash скрипты на Ansible плейбуки, для этого создадим плейбуки **packer_app.yml**, **packer-db.yml**.
  **packer_app.yml**:
 
``` - name: Install Ruby and Build
  hosts: all
  tags: app-tags
  become: true
  vars:
   db_host: 10.132.0.2
  tasks:
   
   - name: Install the package "Ruby-full"
     apt:
      name: ruby-full
      state: present
   - name: Install the package "Ruby-bundler"
     apt:
      name: ruby-bundler
      state: present
   - name: Install the package "Bulid"
     apt:
      name: build-essential
      state: present
```
**packer_db.yml**:

```- name: Install MongoDB
  hosts: all
  tags: db-tag
  become: true
  
  tasks:
   - name: Add an apt key by id from a keyserver
     apt_key:
       keyserver: keyserver.ubuntu.com
       id: EA312927
   - apt_repository:
       repo: deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2    multiverse
       state: present
       filename: 'mongodb-org-3.2'
   - name:  Run the equivalent of "apt-get update" as a separate step
     apt:
      update_cache: yes
   - name: Install the package "MongoDB"
     apt:
       name: mongodb-org
       state: present


  handlers:
   - name: restart mongod
     service: name=mongod state=restarted

```
Заменим секцию _provision_ в образах **app.json** и **db.json**:
```"provisioners": [
    {
    "type": "ansible",
    "playbook_file": "packer_app.yml"
    }
  ]
 ```
   ```"provisioners": [
    {
      "type": "ansible",
      "playbook_file": "packer_db.yml"
    }
  ]
  ```
  ## Homework 10
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
 
