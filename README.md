# rastamalik_infra

Homework 07. \
1.Создал ветку packer-base \
2.Создал директорию config-scripts, перенес скрипты с прошлого ДЗ.\
3.Создал директорию packer, в нее уложил все *.json файлы. \
4.Для создания reddit-base образа, использовал ubuntu16.json \ 
$ packer build ubuntu16.json \
5.Для создания образа с измененными опциями "puma-server", использовал шаблон variables.json \
$ packer build variable.json \
6.Для "запекания" образа все в одном reddit-full, с запущенным приложением создал шаблон immutable.json \
$ packer build immutable.json \
7.Для разворачивания VM машины использовал команду gcloud: \
gcloud compute instances create reddit-full \
--boot-disk-size=20GB \
--image-family reddit-full \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--zone=europe-west1-d \
8.Для автоматизации создания VM машин создал скрипт create-reddit-vm.sh: \
#!/bin/bash \
instance=$1 \
gcloud compute instances create $1 \
--boot-disk-size=20GB \
--image-family reddit-full \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--zone=europe-west1-d \


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

