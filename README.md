# rastamalik_infra

Homework 07.
Создал ветку packer-base
Создал директорию config-scripts, перенес скрипты с прошлого ДЗ.
Создал директорию packer, в нее уложил все *.json файлы.
В директории packer создал поддиректорию scripts, поместил туда скрипты для создания packer образа.
Создал immutable.json, дополнительный скрипт положил для "запекания" в packer/files
Создал скрипт create-reddit-vm.sh, поместил его в config-scripts

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

