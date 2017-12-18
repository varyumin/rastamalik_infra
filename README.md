# rastamalik_infra

gcloud compute instances create reddit-app2 \   
--boot-disk-size=10GB \
--image-family ubuntu-1604-lts \
--image-project=ubuntu-os-cloud \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--metadata startup-script='wget -O - https://gist.github.com/rastamalik/f46a2d70f49fc428f1e6c2e0bce279dc/raw/run_app.sh | bash'


