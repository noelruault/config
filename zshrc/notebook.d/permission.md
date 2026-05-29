
  Please, don't use 777 for permissions, it's a security risk.

    sudo chown $USER:`id -gn` <path/to/folder>

  - $USER will be expanded into your current username.
  - `id -gn` will returns the main group of your current user.

  If any file is owned by root, then it'll require sudo.

  You can check permissions by running:

    ls -l <path/to/folder>

