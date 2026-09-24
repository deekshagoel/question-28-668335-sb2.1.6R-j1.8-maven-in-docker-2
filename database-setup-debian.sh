#!/usr/bin/env bash
# Local development only: MariaDB + MongoDB 8.0 on Debian 12, without systemd.
set -euo pipefail
source /etc/os-release
[[ $ID == debian && $VERSION_ID == 12 ]] || { echo 'Requires Debian 12'; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'Requires x86_64'; exit 1; }
grep -qw avx /proc/cpuinfo || { echo 'MongoDB requires AVX'; exit 1; }
sudo -n true
legacy=/etc/apt/sources.list.d/mongodb-org-4.2.list
if [[ -f $legacy ]] && grep -q 'ubuntu.*bionic' "$legacy"; then
  sudo mv -n "$legacy" "${legacy}.disabled"
fi
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg mariadb-server mariadb-client
curl -fsSL https://pgp.mongodb.com/server-8.0.asc | gpg --batch --dearmor | sudo tee /usr/share/keyrings/mongodb-server-8.0.gpg >/dev/null
echo 'deb [ arch=amd64 signed-by=/usr/share/keyrings/mongodb-server-8.0.gpg ] https://repo.mongodb.org/apt/debian bookworm/mongodb-org/8.0 main' | sudo tee /etc/apt/sources.list.d/mongodb-org-8.0.list >/dev/null
sudo apt-get update
sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y mongodb-org-server mongodb-mongosh
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
sudo mariadb <<'SQL'
CREATE DATABASE IF NOT EXISTS db CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS 'app'@'127.0.0.1' IDENTIFIED BY 'app_dev';
CREATE USER IF NOT EXISTS 'app'@'localhost' IDENTIFIED BY 'app_dev';
GRANT ALL PRIVILEGES ON db.* TO 'app'@'127.0.0.1';
GRANT ALL PRIVILEGES ON db.* TO 'app'@'localhost';
SQL
sudo install -d -o mongodb -g mongodb /var/lib/mongodb /var/log/mongodb
if ! mongosh --quiet --host 127.0.0.1 --eval 'quit(db.adminCommand({ping:1}).ok ? 0 : 1)' >/dev/null 2>&1; then
  sudo -u mongodb mongod --dbpath /var/lib/mongodb --logpath /var/log/mongodb/dev-server.log --bind_ip 127.0.0.1 --port 27017 --auth --fork
fi
if ! mongosh 'mongodb://root:admin@127.0.0.1:27017/admin' --quiet --eval 'db.runCommand({connectionStatus:1})' >/dev/null 2>&1; then
  mongosh --quiet --host 127.0.0.1 --eval 'db.getSiblingDB("admin").createUser({user:"root",pwd:"admin",roles:[{role:"root",db:"admin"}]})'
fi
mongosh 'mongodb://root:admin@127.0.0.1:27017/admin' --quiet --eval 'const d=db.getSiblingDB("db"); if(!d.getUser("app")) d.createUser({user:"app",pwd:"app_dev",roles:[{role:"readWrite",db:"db"}]});'
MYSQL_PWD=app_dev mariadb --protocol=TCP -h 127.0.0.1 -u app db -e 'SELECT VERSION(), DATABASE();'
mongosh 'mongodb://app:app_dev@127.0.0.1:27017/db?authSource=db' --quiet --eval 'db.runCommand({connectionStatus:1}); print("MongoDB " + db.version());'
echo 'Databases ready. Local development login: app / app_dev; database: db.'
