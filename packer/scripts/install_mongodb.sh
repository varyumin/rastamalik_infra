#!/bin/bash
gpg --keyserver keyserver.ubuntu.com --recv EA312927 &&\
gpg --export --armor EA312927 | sudo apt-key add -- &&\
echo "Public key EA312927 has been added" 
bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list' 
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod

