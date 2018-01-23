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

