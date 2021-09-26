#!/bin/bash

docker tag quay.io/jordigilh/centos8-realtime:latest quay.io/kubevirtci/centos8-realtime:latest
docker push quay.io/kubevirtci/centos8-realtime:latest
