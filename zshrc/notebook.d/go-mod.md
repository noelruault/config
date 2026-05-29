
  [INITIALISE GO MODULES]
  go mod init # go mod init <modulename>

  [ADD THE DEPENDENCIES TO THE GO.MOD FILE]
  go get [-v] -u ./...

  [VENDOR THOSE DEPENDENCIES]
  go mod vendor

  [UPDATE A DEPENDENCY]
  go get -u <repo url>
  go mod vendor

  [Reference]: https://www.kablamo.com.au/blog/2018/12/10/just-tell-me-how-to-use-go-modules

  IF Errors when go mod and the repository is private...
  eg:
    $ fatal: could not read Username for 'https://github.com': terminal prompts disabled
    $ reading https://sum.golang.org/lookup/github.com/<name>/<repo_name>@v0.0.0-XXXXXXXXXXXXXX-XXXXXXXXXXXX: 410 Gone
    $ server response: not found: github.com/<name>/<repo_name>@v1.0.0: invalid version: unknown revision v1.0.0

  export GOPRIVATE=github.com/<company_name>/*

  [Reference]: https://stackoverflow.com/a/60323360/4349318
  
