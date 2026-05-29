
  docker exec -it <container1> ping <container2> # names in docker ps and docker compose

  try dkps & dki to inspect containers and images, in a cleaner way.
  #####
  # DOCKER PERMISSION ISSUES?
  # - docker-compose run --rm --service-ports -u root devenv-node-cp
  # - docker run -u root devenv-node-cp
  
