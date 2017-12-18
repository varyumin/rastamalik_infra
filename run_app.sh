#!/bin/bash
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv EA312927 -y 
sudo bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/ap$
sudo apt update
sudo pat install -y mongo-db
sudo systemctl start mongod
sudo systemctl enable mongod
git clone https://github.com/Otus-DevOps-2017-11/reddit.git
cd reddit
bundle install

