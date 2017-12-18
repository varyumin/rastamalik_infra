# rastamalik_infra

gcloud compute instances create reddit-app2 \   
--boot-disk-size=10GB \
--image-family ubuntu-1604-lts \
--image-project=ubuntu-os-cloud \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--metadata startup-script='wget -O - https://gist.github.com/rastamalik/f46a2d70f49fc428f1e6c2e0bce279dc/raw/run_app.sh | bash'


Задание 1. В файл ~/.ssh/config добавил секции

Host bastion Hostname 104.155.69.135 IdentityFile ~/.ssh/appuser user appuser ForwardAgent yes

Host someinternalhost ForwardAgent yes Hostname someinternalhost IdentityFile ~/.ssh/appuser user appuser ProxyCommand ssh -W %h:%p bastion

Задание 2.

Host bastion: внешний IP-104.155.69.135, внутренний IP-10.132.0.2; Host someinternalhost: внутренний IP-10.132.0.3;
