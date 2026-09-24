#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
exec java -Xmx128m -XX:MaxMetaspaceSize=96m -XX:+UseSerialGC -Xss256k -jar target/spring-boot-in-docker.jar "$@"
