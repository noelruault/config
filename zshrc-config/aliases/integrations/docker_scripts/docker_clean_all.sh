#!/bin/bash

# Remove Containers
echo "Stopping containers..."
sudo docker container stop $(docker container ls -aq)

echo "Removing containers..."
sudo docker rm $(sudo docker ps -aq) --force --volumes

# Remove Images
# sudo docker rmi $(sudo docker images -q) --force

# Remove Volumes
echo "Removing volumes..."
docker volume rm $(docker volume ls)

echo "\n[INFO]:"
echo "Remove images with: sudo docker rmi \$(sudo docker images -q) --force"
echo "List Volumes with: docker volume ls"
echo "List docker-compose images with: docker-compose images"
