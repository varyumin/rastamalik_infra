#!/bin/bash
apt update
apt install -y ruby-full ruby-bundler build-essential
gpg --keyserver keyserver.ubuntu.com --recv EA312927 &&\
gpg --export --armor EA312927 | sudo apt-key add -- &&\
echo "Public key EA312927 has been added" 
bash -c 'echo "deb http://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/3.2 multiverse" > /etc/apt/sources.list.d/mongodb-org-3.2.list'
apt update
apt install -y mongodb-org
systemctl start mongod
systemctl enable mongod
git clone https://github.com/Otus-DevOps-2017-11/reddit.git
cd reddit
bundle install
touch /etc/init.d/puma.sh
chmod ugo+x /etc/init.d/puma.sh
bash -c 'echo "#!/bin/bash" > /etc/init.d/puma.sh'
bash -c 'echo "puma -d --dir /home/appuser/reddit" >> /etc/init.d/puma.sh'
sed -i -e  '$i \/etc/init.d/puma.sh \n'  /etc/rc.local
