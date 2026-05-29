
  There are two ways to use the Shebang directive and set the interpreter:

  Using the absolute path to the bash binary:
    /bin/bash

  Using the env utility:
    /usr/bin/env bash
  The advantage of using the second approach is that it will search for the bash
  executable in the user's $PATH environmental variable. If there are more than
  one paths to bash, the first one will be used by the script.
  
