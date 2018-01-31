# rastamalik_infra

## Homework 13
 1. После установки VirtualBox и Vagrant в директории **ansible** создаем файл **Vagrantfile** с определением двух VM:
 ```
 Vagrant.configure("2") do |config|
  config.vm.provider :virtualbox do |v|
    v.memory = 512
  end

  config.vm.define "dbserver" do |db|
    db.vm.box = "ubuntu/xenial64"
    db.vm.hostname = "dbserver"
    db.vm.network :private_network, ip: "10.10.10.10"
    db.vm.provision "ansible" do |ansible|
      ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
        "db" => ["dbserver"],
        "db:vars" => {"mongo_bind_ip" => "0.0.0.0"}
      }
    end
  end
  config.vm.define "appserver" do |app|
    app.vm.box = "ubuntu/xenial64"
    app.vm.hostname = "appserver"
    app.vm.network :private_network, ip: "10.10.10.20"
  end
end
```
2. Создадим виртуалки командой:
```
vagrant up
```
3. Проверим статус VMs:
```
$ vagrant status
Current machine states:
dbserver      running (virtualbox)
appserver     running (virtualbox)
```
4.Провижинг.
Начнем с доработки **db** роли.
Добавим провижининг в определение хоста **dbserver**:
```  ansible.playbook = "playbooks/site.yml"
      ansible.groups = {
        "db" => ["dbserver"],
        "db:vars" => {"mongo_bind_ip" => "0.0.0.0"}
      }
    end
   ```
 5. Добавим еще один плейбук **base.yml**, в котором опишем установку **python**. И добавим его в **site.yml**.
 ```
 ansible/site.yml
---
- include: base.yml
- include: db.yml
- include: app.yml
- include: deploy.yml
```
6.**base.yml**:
```
ansible/playbooks/base.yml (ссылка на gist)
---
- name: Check && install python
hosts: all
become: true
gather_facts: False
tasks:
- name: Install python for Ansible
raw: test -e /usr/bin/python || (apt -y update && apt install -y
python-minimal)
changed_when: False
```
7. Запустим провижинер:
```vagrant provision dbserver```

8. Изменим роль **db**, добавив файл тасков **db/tasks/install_mongo.yml** для установки MongoDB.
Добавим к каждому таску тег **install**, пометив его как шаг установки.
 _db/tasks/install_mongo.yml_
 ```
 - name: Add APT key
  apt_key:
    id: "EA312927"
    keyserver: keyserver.ubuntu.com
  tags: install

- name: Add APT repository
  apt_repository:
    repo: deb [ arch=amd64,arm64 ] http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse
    state: present
  tags: install

- name: Install mongodb package
  apt:
    name: mongodb-org
    state: present
  tags: install

- name: Configure service supervisor
  systemd:
    name: mongod
    enabled: yes
    state: started
tags: install
```
9. Вынесем таски управления конфигом монги в отдельный файл **config_mongo.yml**.
```
db/tasks/config_mongo.yml
---
- name: Change mongo config file
template:
src: templates/mongod.conf.j2
dest: /etc/mongod.conf
mode: 0644
notify: restart mongod
```
10. В файле main.yml роли будем вызывать таски в нужном нам порядке:
```
db/tasks/main.yml
---
# tasks file for db
- name: Show info about the env this host belongs to
debug:
msg: "This host is in {{ env }} environment!!!"
- include: install_mongo.yml
- include: config_mongo.yml
 ```
 11.Включим в нашу роль **app** конфигурацию из **packer_app.yml** плейбука, необходимую для настройки хоста приложения.
 Создадим новый файл для тасков **ruby.yml** внутри роли **app** и скопируем в него таски из плейбука **packer_app.yml**.
```
---
- name: Install ruby and rubygems and required packages
  apt: "name={{ item }} state=present"
  with_items:
    - ruby-full
    - ruby-bundler
    - build-essential
  tags: ruby
  ```
  12. Создадим файл **app/tasks/puma.yml**
  ```
  app/tasks/puma.yml
---
- name: Add unit file for Puma
copy:
src: puma.service
dest: /etc/systemd/system/puma.service
notify: reload puma
- name: Add config for DB connection
template:
src: db_config.j2
dest: /home/appuser/db_config
owner: appuser
group: appuser
- name: enable puma
systemd: name=puma enabled=yes
 ```
13. В файле main.yml роли будем вызывать таски в нужном нам порядке:
```
app/tasks/main.yml
---
# tasks file for app
- name: Show info about the env this host belongs to
debug:
msg: "This host is in {{ env }} environment!!!"
- include: ruby.yml
- include: puma.yml
 ```
 14. Определим **Ansible** провижинер для хоста **appserver** в **Vagrantfile**:
 ```
 ansible/Vagrantfile
...
...
config.vm.define "appserver" do |app|
app.vm.box = "ubuntu/xenial64"
app.vm.hostname = "appserver"
app.vm.network :private_network, ip: "10.10.10.20"
app.vm.provision "ansible" do |ansible|
ansible.playbook = "site.yml"
ansible.groups = {
"app" => ["appserver"],
"app:vars" => { "db_host" => "10.10.10.10"}
}
end
end
```
15. Применим провижинг для **appserver**:
``` vagrant provision appserver ```
16. Для подключения к БД параметризируем роль:
```
app/defaults/main.yml
---
# defaults file for app
db_host: 127.0.0.1
env: local
deploy_user: appuser
```
17. Заменим модуль для копирования unit файла с copy на template, чтобы иметь возможность параметризировать unit файл:
```
app/tasks/puma.yml
---
- name: Add unit file for Puma
template:
src: puma.service.j2
dest: /etc/systemd/system/puma.service
notify: reload puma
```
18. Переместим его из директории **app/files** в директорию **app/templates**, т.к. мы поменяли используемый для копирования модуль и добавим к файлу **puma.service** расширение **.j2**, чтобы обозначить данный файл как шаблон.
Заменим в созданном шаблоне все упоминания **appuser** на переменную **deploy_user**:
```
app/templates/puma.service.j2

[Unit]
Description=Puma HTTP Server
After=network.target
[Service]
Type=simple
EnvironmentFile=/home/{{ deploy_user }}/db_config
User={{ deploy_user }}
WorkingDirectory=/home/{{ deploy_user }}/reddit
ExecStart=/bin/bash -lc 'puma'
Restart=always
[Install]
WantedBy=multi-user.target
```
19. Параметризируем **app/tasks/puma.yml**
```
app/tasks/puma.yml
---
- name: Add unit file for Puma
template:
src: puma.service.j2
dest: /etc/systemd/system/puma.service
notify: reload puma
- name: Add config for DB connection
template:
src: db_config.j2
dest: "/home/{{ deploy_user }}/db_config"
owner: "{{ deploy_user }}"
group: "{{ deploy_user }}"
- name: enable puma
systemd: name=puma enabled=yes
```
20. Параметризируем **ansible/playbooks/deploy.yml**
```
ansible/playbooks/deploy.yml
---
- name: Deploy App
hosts: app
vars:
deploy_user: appuser
tasks:
- name: Fetch the latest version of application code
git:
repo: 'https://github.com/Otus-DevOps-2017-11/reddit.git'
dest: "/home/{{ deploy_user }}/reddit"
version: monolith
notify: restart puma
- name: bundle install
bundler:
state: present
chdir: "/home/{{ deploy_user }}/reddit"
handlers:
- name: restart puma
become: true
systemd: name=puma state=restarted
```
21. Добавим **extra_vars** **deploy_user vagrant** переменные в блок определения провижинера в **Vagrantfile**:
```
ansible/Vagrantfile
...
app.vm.provision "ansible" do |ansible|
ansible.playbook = "site.yml"
ansible.groups = {
"app" => ["appserver"],
"app:vars" => { "db_host" => "10.10.10.10"}
}
ansible.extra_vars = {
"deploy_user" => "vagrant"
}
end
```
22. Проверим провижинг для хоста **appserver**
```vagrant provision appserver```
21.Проверим конфигурацию, удалим VM ```vagrant destroy -f``` и создадим окружение и проверим, что все деплоится ```vagrant up```

22. Добавим конфигурацию для корректной работы проксирования приложения с помощью **nginx** в плейбук **app.yml** добавим :

```
---
- name: Configure App
  hosts: app
  become: true
  vars:
   db_host: 10.10.10.10
  roles:
    - role: app
    - role: ~/.ansible/roles/jdauphant.nginx

      nginx_sites:
       default:
        - listen 80
        - server_name "reddit"
        - location / { proxy_pass http://127.0.0.1:9292; }
      state: present
      notify:
       - reload nginx
 ```
 23. Тестирование ролей.
 Установка зависимостей, добавим в файл **requirements.txt** в директории **ansible** следующие записи:
```
ansible/requirements.txt
ansible>=2.4
molecule>=2.6
testinfra>=1.10
python-vagrant>=0.5.15

```
И установим:
```
$ pip install -r requirements.txt
$ molecule --version
molecule, version 2.7.0
$ ansible --version
ansible 2.4.x.x
```
24. Используем команду **molecule init** для создания заготовки тестов для роли **db**. Выполним команду ниже в директории с ролью **ansible/roles/db**:
```
molecule init scenario --scenario-name default -r db -d vagrant
```
25. Добавим несколько тестов, используя модули **Testinfra**, для проверки конфигурации, настраиваемой ролью **db**:
```
db/molecule/default/tests/test_default.py
...
# check if MongoDB is enabled and running
def test_mongo_running_and_enabled(host):
mongo = host.service("mongod")
assert mongo.is_running
assert mongo.is_enabled

# check if configuration file contains the required line
def test_config_file(File):
config_file = File('/etc/mongod.conf')
assert config_file.contains('bindIp: 0.0.0.0')
assert config_file.is_file
```
26. Описание тестовой машины, которая создается **Molecule** для тестов содержится в файле **db/molecule/default/molecule.yml**
27. Создадим VM для проверки роли. В директории **ansible/roles/db** выполните команду:
```
$ molecule create
```
28. **Molecule init** генерирует плейбук для применения нашей роли. Данный плейбук можно посмотреть по пути **db/molecule/default/playbook.yml**. Дополнительно зададим еще переменную **mongo_bind_ip**.
```
---
- name: Converge
become: true
hosts: all
vars:
mongo_bind_ip: 0.0.0.0
roles:
- role: db
```
29. Применим конфигурацию:
```
molecule converge
```
30. Прогоним тесты:
```
molecule verify
```
31. Добавим тест к роли **db** для проверки того, что БД слушает по нужному порту (27017) в файл **test_default.py** добавим строки:
```
def test_mongo_port(Socket):
    assert Socket("tcp://0.0.0.0:27017").is_listening
 ```

32. Используем роли **db** и **app** в шаблонах **packer** - **app.json и db.json**:
```
"provisioners": [
    {

      "type": "ansible",
      "ansible_env_vars": ["ANSIBLE_ROLES_PATH={{ user `ansible_path` }}/ansible/roles"],
      "playbook_file": "packer_app.yml"
    }
  ]
}
```
параметр ansible_path прописал в **variables.json**
```
{
"project_id1": "clever-overview-188908",
"source_image_family1": "ubuntu-1604-lts",
"machine_type1": "g1-small",
"zone1": "europe-west1-b",
"ansible_path": "~/rastamalik_infra"
}
```
33. Задание со звездочкой:
Создал репозиторий **test-ansible-role-with-travis** из вынесенной роли **db**, подключил **TravisCL** для прогона тестов в GCE,
файл **.travis.yml**:
```
Language: python
python:
- '2.7'
install:
- sudo pip install six --upgrade
- pip install --user ansible==2.3.0 molecule apache-libcloud==0.20.1 backports.ssl_match_hostname testinfra==1.10.0 pytest==3.3.2
env:
  matrix:
  - GCE_CREDENTIALS_FILE="$(pwd)/credentials.json"
  global:
  - secure: 042a071ee7fe58c663acd32c7c5b7c1ee852d8c5
  - secure: d2af1bb7094e9aaa4a4ad96e7b17d682e8cbc1c7
   - secure: QIUJL4fzU0TVEKInJl1JeluLXaTsi+5nqEootxU9z6b9dpVmMZqCrSqTU5NGRCJ35L9U3Y6DVFdPRZmb5OaQG+wvO/yEh1ypOcdo6O/D8ZCvLXD+  -
script:
- molecule  create
- molecule converge
- molecule  verify
after_script:
 - molecule destroy
before_install:
- openssl aes-256-cbc -K $encrypted_8d879a3c5c12_key -iv $encrypted_8d879a3c5c12_iv
  -in secrets.tar.enc -out secrets.tar -d
- tar xvf secrets.tar
- mv google_compute_engine /home/travis/.ssh/
- chmod 0600 /home/travis/.ssh/google_compute_engine
```
Тест проходит, бейдж с успешным билдом в **README.md**.

34. Оповещение в Slack так и не получилось.




## Homework 12
1. В директории **ansible** создаем директорию **roles** и выполняем команды:
```ansible-galaxy init app```
```ansible-galaxy init db```
2. Создадим роль для конфигурации MongoDB.
Скопируем секцию _tasks_ в сценарии плейбука **ansible/db.yml** и вставим ее в директорию **tasks** роли **db** в _main.yml_:
```---
  - name: Show info about the env this host belongs to
    debug:
      msg: "This host is in {{ env }} environment!!!"
  - name: Change mongo config file
    become: true
    template:
          src: mongod.conf.j2
          dest: /etc/mongod.conf
          mode: 0644
    notify: restart mongod


# tasks file for db
```
3. Создадим директорию для шаблонов **templates** в директории роли **ansible/roles/db** и скопируем туда конфиг для MongoDB из директории **ansible/templates**
```
	db_config.j2
	mongod.conf.j2
```
4. Определим хендлер в директории handlers роли **ansible/roles/db/handlers/main.yml**:
```
# handlers file for db
-
name:
 restart mongod
service:
 name=mongod state=restarted
```
5. Определим используемые в шаблоне переменные в секции переменных по умолчанию:

**ansible/roles/db/defaults/main.yml**
```
---
# defaults file for db
mongo_port:
 27017
mongo_bind_ip:
127.0.0.1
```
6. Создадим роль для управления инстанса приложения. Скопируем секцию _tasks_ в сценарии плейбука **ansible/app.yml** и вставим ее в файл для тасков роли **app** в _main.yml_:
```
---
  - name: Show info about the env this host belongs to
    debug:
      msg: "This host is in {{ env }} environment!!!"

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

# tasks file for app
```
7. Создадим директорию для шаблонов **templates** и директорию для файлов **files** в директории роли **ansible/roles/app**. Скопируйте файл **db_config.j2** из директории **ansible/templates** в директорию **ansible/roles/app/templates**, файл **ansible/files/puma.service** скопируем в **ansible/roles/app/files**.
8. Определим хендлер в **app**:
```
ansible/roles/app/handlers/main.yml
---
# handlers file for app
- name: reload puma
systemd: name=puma state=reloaded
```
9. Зададим адрес поключения к MongoDB:
```
ansible/roles/app/defaults/main.yml
---
# defaults file for app
db_host: 127.0.0.1
```
10.Удалим определение тасков и хендлеров в плейбуке **ansible/app.yml** и заменим на вызов роли:
```
ansible/app.yml
---
- name: Configure App
hosts: app
become: true
vars:
db_host: 10.132.0.2
roles:
- app
```
```
ansible/db.yml
---
- name: Configure MongoDB
hosts: db
become: true
vars:
mongo_bind_ip: 0.0.0.0
roles:
- db
```
11. Для проверки роли пересоздадим инфраструктуру окружения **stage**, используя команды:
```
terraform destroy
terraform apply -auto-approve=false
```
12. Проверка и применение ролей:
```
ansible-playbook site.yml --check
ansible-playbook site.yml
```
13. Создадим директорию **environments** в директории **ansible** для определения настроек окружения. В директории **ansible/environments** создадим две директории для наших окружений **stage** и **prod**.
14. Скопируем инвентори файл **ansible/inventory** в каждую из директорий окружения **environtents/prod** и **environments/stage**. Сам файл **ansible/inventory** при этом удалим.
15. чтобы задеплоить приложение на **prod** окружении мы должны теперь написать:
```
ansible-playbook -i environments/prod/inventory deploy.yml
```
16. Определим окружение по умолчанию в конфиге **Ansible**:
```
ansible/ansible.cfg
[defaults]
inventory = ./environments/stage/inventory
remote_user = appuser
private_key_file = ~/.ssh/appuser
host_key_checking = False
```
17. Создадим директорию **group_vars** в директориях наших окружений **environments/prod** и **environments/stage**.
Создадим файлы **stage/group_vars/app** для определения переменных для группы хостов **app**,описанных в инвентори файле **stage/inventory**.

18. Скопируем в этот файл переменные, определенные в плейбуке **ansible/app.yml**. Определение переменных из самого плейбука **ansible/app.yml** удалим:
```
ansible/environments/stage/group_vars/app
db_host: 10.132.0.2
```
Аналогично определим переменные для БД:
```
ansible/environments/stage/group_vars/db
mongo_bind_ip: 0.0.0.0
```
19. Создадим файл **stage/group_vars/all**:
```
ansible/environments/stage/group_vars/all
env: stage
```
20. Конфигурация окружения **prod** будет идентичной.
В файле **prod/group_vars/all** измените значение **env** переменной на **prod**:
```
env: prod
```
21. Определим переменную по умолчанию env в используемых ролях:
```
ansible/roles/app/defaults/main.yml
---
# defaults file for app
db_host: 127.0.0.1
env: local
ansible/roles/db/defaults/main.yml
---
# defaults file for db
mongo_port: 27017
mongo_bind_ip: 127.0.0.1
env: local
```
22. Добавим следующий таск в начало наших ролей. Для роли **app**:
```
ansible/roles/app/tasks/main.yml
---
# tasks file for app
- name: Show info about the env this host belongs to
debug:
msg: "This host is in {{ env }} environment!!!"
```
Добавим такой же таск в роль **db**:
```
ansible/roles/db/tasks/main.yml
---
# tasks file for db
- name: Show info about the env this host belongs to
debug:
msg: "This host is in {{ env }} environment!!!"
```
23. Перенесем все плейбуки в отдельную директорию согласно **best practices**. Создадим директорию **ansible/playbooks** и перенесем туда все наши плейбуки, в том числе из прошлого ДЗ. В директории **ansible** у нас остались еще файлы из прошлых ДЗ, которые нам не особо нужны. Создадим директорию **ansible/old** и перенесем туда все, что не относится к текущей конфигурации.
В папке **ansible** из файлов остается только **ansible.cfg и requirements.txt**.

24. Для проверки пересоздадим инфраструктуру окружения **stage**, используя команды:
```
terraform destroy
terraform apply -auto-approve=false
```
```
ansible-playbook playbooks/site.yml --check
ansible-playbook playbooks/site.yml
```
25. Проверим окружение **prod**:
```
ansible-playbook -i environments/prod/inventory playbooks/site.yml --check
ansible-playbook -i environments/prod/inventory playbooks/site.yml
```
26. Работа с **ansible-galaxy**.
Используем роль **jdauphant.nginx** и настроим проксирование нашего приложения с помощью **nginx**.

Создадим файлы **environments/stage/** **requirements.yml** и **environments/prod/requirements.yml**:
Добавим в них запись вида:
```
---
- src: jdauphant.nginx
version: v2.13
```
27. Установим роль:
```
ansible-galaxy install -r environments/stage/requirements.yml
```
28. Добавим переменные в **stage/group_vars/app и prod/group_vars/app**:
```
nginx_sites:
default:
- listen 80
- server_name "reddit"
- location / {
proxy_pass http://127.0.0.1:порт_приложения;
}
```
29.**Самостоятельное задание**:
Добавим вызов роли в **app.yml**:
```
---
- name: Configure App
  hosts: app
  become: true
  vars:
   db_host: 10.10.10.10
  roles:
   - app
- ~/.ansible/roles/jdauphant.nginx
```


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

