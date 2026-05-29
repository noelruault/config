
  As an advice, just install mysql client and let the server to be instantiated by Docker.
    $ brew install mysql-client
  To find out where is the file 'my.cnf' being loaded, run the next command:
    $ mysql --help | grep my.cnf -B2

  An usual error like the next can be found when using mysql:
    MySQL said: Authentication plugin 'caching_sha2_password' cannot be loaded:
    dlopen(/usr/local/lib/plugin/caching_sha2_password.so, 2): image not found
  Can be fixed by adding the next lines to the my.cnf file:
    [mysqld]
    default-authentication-plugin=mysql_native_password

  Login to mysql server from terminal: run mysql -u root -p, then inside shell execute this command
  (replacing [password] with your actual password): ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '[password]';
    $ ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '';

  exit from mysql shell with exit and run:
    $ brew services restart mysql

-----------
  When insalling the server, MySQL is configured to only allow
  connections from localhost by default, to connect run:
      $ mysql -uroot
  To have launchd start mysql now and restart at login:
    $ brew services start mysql
  Or, if you don't want/need a background service you can just run:
    $ mysql.server start
      $ /usr/local/bin/mysql.server start

    https://stackoverflow.com/a/55692783/4349318

  ERROR 2002 (HY000): Can't connect to local MySQL server through socket '/tmp/mysql.sock' ?
    - https://stackoverflow.com/a/34709790/4349318
  
