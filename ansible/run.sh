#!/bin/bash
docker build -f Containerfile -t hive-ansible .
docker run -ti --rm -v /home/nold/.ssh:/home/nold/.ssh hive-ansible
