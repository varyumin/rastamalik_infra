#!/bin/bash
instance=$1
packer build immutable.json
gcloud compute instances create $1 \
--boot-disk-size=20GB \
--image-family reddit-full \
--machine-type=g1-small \
--tags puma-server \
--restart-on-failure \
--zone=europe-west1-d

