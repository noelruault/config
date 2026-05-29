
  Installing extra Go versions

  It may be useful to have multiple Go versions installed on the same machine, for example, to ensure that a package's tests pass on multiple Go versions. Once you have one Go version installed, you can install another (such as 1.10.7) as follows:

    $ go get golang.org/dl/go1.10.7
    $ go1.10.7 download

  The newly downloaded version can be used like go:

    $ go1.10.7 version
    go version go1.10.7 linux/amd64

  All Go versions available via this method are listed on the download page. You can find where each of these extra Go versions is installed by looking at its GOROOT; for example, go1.10.7 env GOROOT. To uninstall a downloaded version, just remove its GOROOT directory and the goX.Y.Z binary.


  SOURCE: https://golang.org/doc/install#extra_versions
  
