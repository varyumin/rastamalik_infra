# rastamalik_infra
Homework 09
1. Создал файл inventory.yml с содержимым: \
app: \
 hosts: \
  appserver:\
   ansible_host: 35.205.71.79 \
db: \
 hosts: \
  dbserver: \
   ansible_host: 35.195.224.187 \
2.Создал файл inventory.json с содержимым: \
{ \
"app": { \
  "hosts": { \
     "appserver": {  \
"ansible_host": "35.205.71.79" \
} \
} \
}, \
"db": { \
 "hosts": { \ 
 "dbserver": { \ 
"ansible_host": "35.195.224.187" \
} \
} \
},\
} \ 
3. Вывод команды ansible all -m ping -i inventory.yml и inventory.json \
appserver | SUCCESS => { \
    "changed": false,  \
    "ping": "pong" \
} \
dbserver | SUCCESS => { \
    "changed": false, \
    "ping": "pong" \
} \

_________________________________________________________________________________________________


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

