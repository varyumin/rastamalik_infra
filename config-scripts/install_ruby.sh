#!/bin/bash
sudo apt remove ruby-full ruby-bundler build-essential -y
sudo apt update
sudo apt install -y ruby-full ruby-bundler build-essential
ruby -v
bundle -v

