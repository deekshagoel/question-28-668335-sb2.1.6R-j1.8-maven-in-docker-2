#!/usr/bin/env bash
# Rebuild this project in the BarRaiser Debian 12 IDE. Run: bash setup.sh
set -euo pipefail
cd "$(dirname "$0")"
source /etc/os-release
[[ $ID == debian && $VERSION_ID == 12 ]] || { echo 'This setup requires Debian 12.' >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || { echo 'This setup requires x86_64.' >&2; exit 1; }
sudo -n true || { echo 'Passwordless sudo is required in this IDE.' >&2; exit 1; }

echo '==> Checking Java 8 and Maven'
if ! { command -v java >/dev/null && java -version 2>&1 | grep -q 'version "1\.8\.' && command -v javac >/dev/null && javac -version 2>&1 | grep -q '^javac 1\.8\.'; }; then
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y ca-certificates curl gnupg
  curl -fsSL https://apt.corretto.aws/corretto.key | gpg --batch --dearmor | sudo tee /usr/share/keyrings/corretto-keyring.gpg >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/corretto-keyring.gpg] https://apt.corretto.aws stable main' | sudo tee /etc/apt/sources.list.d/corretto.list >/dev/null
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y java-1.8.0-amazon-corretto-jdk
  java_bin=$(dpkg -L java-1.8.0-amazon-corretto-jdk | grep '/bin/java$' | head -n 1)
  [[ -n $java_bin ]] || { echo 'Corretto 8 binary was not found after installation.' >&2; exit 1; }
  export JAVA_HOME=${java_bin%/bin/java}
  export PATH="$JAVA_HOME/bin:$PATH"
fi
if ! command -v mvn >/dev/null; then
  sudo apt-get update
  sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y maven
fi
java -version
javac -version
mvn -version
mvn -version | grep -q 'Java version: 1.8.' || { echo 'Maven is not using Java 8.' >&2; exit 1; }

echo '==> Installing and starting MariaDB and MongoDB'
bash database-setup-debian.sh

echo "==> Stopping previous application before rebuilding"
while read -r app_pid; do
  [[ -n $app_pid ]] || continue
  [[ $(ps -p "$app_pid" -o comm= 2>/dev/null | tr -d ' ') == java ]] || continue
  [[ $(readlink -f "/proc/$app_pid/cwd" 2>/dev/null || true) == "$PWD" ]] || continue
  kill -TERM "$app_pid"
  for attempt in {1..30}; do
    if ! kill -0 "$app_pid" 2>/dev/null; then break; fi
    sleep 1
  done
  kill -0 "$app_pid" 2>/dev/null && { echo 'Previous application did not stop.' >&2; exit 1; }
done < <(pgrep -f 'java.*spring-boot-in-docker.jar' || true)

echo '==> Building and testing with one bounded Maven JVM'
mvn -B -DforkCount=0 -Dtest=DatabaseConnectivityIT clean package

echo '==> Starting the API on port 8081'
nohup bash run-app.sh > /tmp/project-api.log 2>&1 &
app_pid=$!
printf '%s\n' "$app_pid" > /tmp/project-api.pid
ready=false
for attempt in {1..60}; do
  if curl -fsS --max-time 2 http://127.0.0.1:8081/ >/dev/null 2>&1; then ready=true; break; fi
  if ! kill -0 "$app_pid" 2>/dev/null; then break; fi
  sleep 1
done
$ready || { tail -80 /tmp/project-api.log >&2; echo 'API startup failed.' >&2; exit 1; }

echo '==> Verifying POST and GET against both databases'
bash verify-api.sh
echo 'Setup complete. API: http://127.0.0.1:8081/api/records'
