# Databases in the BarRaiser Debian 12 IDE

Run commands from this repository directory. Java 8 and Maven remain unchanged.
The original database-setup.sh targets Ubuntu and must not be used in this IDE.
Docker and systemd are not required by these replacement scripts.

## First setup

    bash database-setup-debian.sh

Installs Debian MariaDB 10.11 and MongoDB 8.0 from MongoDB's signed Debian
repository, starts them bound to 127.0.0.1 with authentication, and creates db.
The obsolete Ubuntu MongoDB apt source is retained as a .disabled file.
Existing database data is not deleted and existing user passwords are not reset.

## Start after a room/container restart

    bash database-start.sh

If the provider rebuilds the container and the database binaries are missing,
run the setup script again. These scripts do not guarantee that BarRaiser keeps
data when the room is reset, rebuilt, or ended. Export needed data beforehand.
Data directories: /var/lib/mysql and /var/lib/mongodb.
Logs: /var/lib/mysql/dev-server.log and /var/log/mongodb/dev-server.log.

## Application connection settings

Both application accounts use username app, password app_dev, database db.
MariaDB: 127.0.0.1:3306, jdbc:mariadb://127.0.0.1:3306/db.
MongoDB: mongodb://app:app_dev@127.0.0.1:27017/db?authSource=db.
MongoDB's setup administrator is root/admin in the admin authentication DB.
These are disposable development credentials. Do not expose database ports
through the IDE or use these defaults for production.
Application settings support DB_USER, DB_PASSWORD, and MONGODB_URI overrides;
changing those variables alone does not change the accounts on the servers.

The pom now uses MariaDB Connector/J 2.7.13, removes test-only scope from
both Spring Data starters, and pins MongoDB driver 3.12.14 to retain the
Spring Boot 2.1 / Java 8 API. This is a legacy stack: passing the CRUD checks
is not a claim of full vendor support for all MongoDB 8.0 features.
For a maintained production application, upgrade Spring Boot and its driver
together. Do not replace this MongoDB installation with 8.1+ on driver 3.x.
Hibernate uses MariaDB103Dialect and ddl-auto=update so restarts do not
drop tables. Use schema migrations for production.

## Verify actual Java writes and reads

    mvn -DforkCount=0 -Dtest=DatabaseConnectivityIT test

This starts the Spring context and tests one insert/read in each real database.
It cleans up only its own UUID-tagged rows/documents. The empty
database_setup_probe SQL table and MongoDB collection are retained.
The test is opt-in and is not part of the normal unit-test naming pattern.

## Build and run

    mvn clean package
    bash run-app.sh

If an old application is already listening on 8081, stop that application's
terminal with Ctrl+C before starting the new jar.


## Working POST and GET endpoints

Port 8080 belongs to code-server in this IDE; the application uses 8081.
To create a record in both databases, run in the cloud IDE terminal:

    curl -i -X POST http://127.0.0.1:8081/api/records \
      -H 'Content-Type: application/json' \
      -d '{"id":"demo-001","name":"Deeksha","message":"Hello from both databases"}'

Expected: HTTP 201, {"id":"demo-001","storedIn":["mariadb","mongodb"]}.

    curl -i http://127.0.0.1:8081/api/records/demo-001

Expected: HTTP 200 with id and separate mariadb/mongodb objects containing
id, name, and message. Both objects are fetched from their actual databases.
The same ID is the MariaDB primary key and MongoDB _id; IDs are strings,
case-sensitive, and contain only letters, numbers, hyphens or underscores.
Max lengths: id 64, name 100, message 500; all fields are required and nonblank.

HTTP 400: invalid input. HTTP 404: absent in both databases.
HTTP 409: duplicate ID on POST, or incomplete/different copies on GET.
Database access failures return HTTP 503. Use a new ID for each POST.
SQL writes run in a transaction and roll back if the Mongo insert fails,
but the two stores do not share an atomic distributed transaction.

    bash verify-api.sh

This checks create/read, equality of both copies, duplicate IDs, invalid input,
missing IDs, and a string ID shaped like a Mongo ObjectId. It leaves its
uniquely named sample records available for inspection.

This 1 GB IDE requires bounded Java memory: .mvn/jvm.config caps Maven, and
run-app.sh caps the application. Stop the application before rebuilding or
running the integration test to leave memory available for Maven. Use
-DforkCount=0 for the integration test to avoid launching a second JVM.

## Verified in this room

MariaDB 10.11.18 and MongoDB 8.0.32 both accepted authenticated Java writes
and reads. The two DatabaseConnectivityIT tests passed with zero failures.
The packaged application passed all verify-api.sh checks, including matching
responses from both stores and HTTP 201/200/409/404/400 behavior.
The application was launched with bash run-app.sh on port 8081.
Runtime log: /tmp/project-api.log.
These source changes are in the cloud workspace; they have not been pushed
to GitHub. Commit or download them before ending/resetting the room.
