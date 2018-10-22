#!/bin/bash
sudo docker rm $(sudo docker ps -a -q) -f
sudo docker rmi $(sudo docker images -q) -f
cd $PROJECT_PATH && sudo find . -name \*.pyc -print -delete
# && rm scripts/data.cache
