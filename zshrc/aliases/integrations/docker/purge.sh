#!/bin/bash

# remove all exited containers
docker rm $(docker ps -q -f status=exited)
# remove unnamed images
docker rmi $(docker images -a | grep "^<none>" | awk '{print $3}') --force
