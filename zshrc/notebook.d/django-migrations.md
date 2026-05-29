
  [MIGRATIONS]

  [ROLLBACK]
  python manage.py showmigrations
  python manage.py migrate <app_name> <old_migration>
  rm <app_name>/migrations/<last_migration>.py

  [MIGRATE]
  python manage.py makemigrations <app_name> --name=<name>  # python manage.py makemigrations
  python manage.py migrate <app_name>  # python manage.py migrate

  [[Source: https://stackoverflow.com/questions/32123477/django-revert-last-migration]]
  
