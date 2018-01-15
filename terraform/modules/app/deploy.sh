#!/bin/bash
db=$DATABASE_URL
set -e
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
APP_DIR=${1:-$HOME}

git clone https://github.com/Otus-DevOps-2017-11/reddit.git $APP_DIR/reddit
cd $APP_DIR/reddit
export DATABASE_URL=$DATABASE_URL
bundle install
sudo mv /tmp/puma.service /etc/systemd/system/puma.service
sudo systemctl start puma
sudo systemctl enable puma

