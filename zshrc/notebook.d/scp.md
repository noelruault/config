
  If you want to copy a directory from machine a to b while logged into a:
    scp -r /path/to/directory user@ipaddress:/path/to/destination
    rsync -r -v --progress -e ssh user@remote-system:/address/to/remote/file /path/to/destination

  If you want to copy a directory from machine a to b while logged into b:
    scp -r user@ipaddress:/path/to/directory /path/to/destination
    rsync -r -v --progress -e ssh /path/to/destination user@remote-system:/address/to/remote/file
  
