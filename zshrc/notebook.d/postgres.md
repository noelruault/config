
  [ https://hackernoon.com/dont-install-postgres_docker-pull-postgres-bee20e200198 ]

  [CONNECT]
    - psql [-U/--username] <user_name> [(optional)--dbname]<database_name> --host localhost
    - psql ... [-W/--password] # force password prompt (should happen automatically)

  [RULES]
  Show all rules in the database
    SELECT * from pg_rules;

  [TABLES]
  List tables
    - \dt
  Show a table and its rules
    - \d <table_name>

  [DATABASES]
  List databases (shows all tables in the current schema)
    - \l
  Connect to database
    - \c <database_name>

  [SCHEMA]
  List schemas
    - \dn
  Display/describe schema:
    - \dt <schema_name>.*
    * https://stackoverflow.com/a/15644918/4349318

  [DROP]
  (ALL TABLES):
    - drop schema <schema_name> cascade;
    - create schema <schema_name>;

  [EXAMPLES]
  Select query examples:
    $ SELECT current_database(); # Displays name of current DB
    $ SELECT * FROM portal_user WHERE user_id = 1;

    $ UPDATE portal_user SET password = abc1234... WHERE user_id = 1;
    $ UPDATE <table> SET <column> = <value> WHERE <column> = <value>;

  [SETUP & DEAMONS info]
  *** SETUP
  psql: error: FATAL:  database "xyz" does not exist
      /usr/local/opt/postgres/bin/createuser -s postgres

  PGUSER=postgres psql
  [Source: https://stackoverflow.com/a/17646333]

  *** DAEMONS
    # To migrate existing data from a previous major version of PostgreSQL run:
    #   brew postgresql-upgrade-database

    # To have launchd start postgresql now and restart at login:
    #   brew services <start/stop> postgresql
    # Or, if you don't want/need a background service you can just run:
    #   pg_ctl -D /usr/local/var/postgres <start/stop> # -D flags the location of the database storage area

  
