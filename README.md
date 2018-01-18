# rastamalik_infra
##Homework 11
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
  
  6. Изменим _provision_ в **Packer** bash скрипты на Ansible плейбуки, для этого создадим плейбуки **packer_app
  
 
