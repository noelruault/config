#!/bin/bash

# Remove Containers
sudo docker container stop $(docker container ls -aq)
sudo docker rm $(sudo docker ps -aq) --force --volumes
# Remove Images
# sudo docker rmi $(sudo docker images -q) --force
# Remove Volumes
docker volume rm $(docker volume ls)


if [  -z "$PROJECT_PATH" ]; then
	# cd $HOME/Work/ && sudo find . -name \*.pyc -print -delete
	echo """
	PROJECT_PATH is empty, specify PROJECT_PATH
	"""
else
	cd $PROJECT_PATH && sudo find . -name \*.pyc -print -delete
	echo "PROJECT_PATH set to $PROJECT_PATH"
fi

# && rm scripts/data.cache


# $ docker rm --help
#   Options:
#     -f, --force     Force the removal of a running container (uses SIGKILL)
#     -l, --link      Remove the specified link
#     -v, --volumes   Remove the volumes associated with the container

# $ docker rmi --help
#   Options:
#     -f, --force      Force removal of the image
#     --no-prune   Do not delete untagged parents

echo "\n[INFO]:"
echo "Remove images with: sudo docker rmi \$(sudo docker images -q) --force"
echo "List Volumes with: docker volume ls"
echo "List docker-compose images with: docker-compose images"