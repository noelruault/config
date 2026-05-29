
  docker-compose run --rm --service-ports --name <name> <name>
  go build -mod=vendor ./cmd/<name> && ./<name> -v
  
