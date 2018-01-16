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
