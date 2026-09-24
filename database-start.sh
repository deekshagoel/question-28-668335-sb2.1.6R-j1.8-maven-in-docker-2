#!/usr/bin/env bash
# Restart already-installed local databases after a workspace/container restart.
set -euo pipefail
sudo install -d -o mysql -g mysql /run/mysqld
if ! sudo mariadb-admin ping --silent >/dev/null 2>&1; then
  sudo -u mysql nohup mariadbd --datadir=/var/lib/mysql --socket=/run/mysqld/mysqld.sock --pid-file=/run/mysqld/mysqld.pid --bind-address=127.0.0.1 --port=3306 --log-error=/var/lib/mysql/dev-server.log </dev/null >/dev/null 2>&1 &
fi
ready=false
for i in {1..60}; do
  if sudo mariadb-admin ping --silent >/dev/null 2>&1; then ready=true; break; fi
  sleep 1
done
$ready || { sudo tail -50 /var/lib/mysql/dev-server.log; exit 1; }
if ! mongosh --quiet --host 127.0.0.1 --eval 'quit(db.adminCommand({ping:1}).ok ? 0 : 1)' >/dev/null 2>&1; then
  sudo -u mongodb mongod --dbpath /var/lib/mongodb --logpath /var/log/mongodb/dev-server.log --bind_ip 127.0.0.1 --port 27017 --auth --fork
fi
MYSQL_PWD=app_dev mariadb --protocol=TCP -h 127.0.0.1 -u app db -e 'SELECT VERSION(), DATABASE();'
mongosh 'mongodb://app:app_dev@127.0.0.1:27017/db?authSource=db' --quiet --eval 'print("MongoDB " + db.version());'
