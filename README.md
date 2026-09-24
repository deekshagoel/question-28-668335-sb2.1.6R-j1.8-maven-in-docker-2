# Spring Boot API with MariaDB and MongoDB

This project runs in the BarRaiser Debian 12 cloud IDE. From the repository directory, set up Java 8, Maven, MariaDB, MongoDB, build the JAR, start the app, and verify both database connections with one command:

    bash setup.sh

The setup can be run again after a room restart. It keeps existing database data and checks that POST and GET work through both databases. The API listens on port 8081 because the IDE uses 8080. The app runs in the background; its log is at `/tmp/project-api.log`. The IDE may not retain database files after a room rebuild, so export data you need to keep.

To write one record into both databases:

    curl -i -X POST http://127.0.0.1:8081/api/records \
      -H 'Content-Type: application/json' \
      -d '{"id":"demo-001","name":"Deeksha","message":"Hello from both databases"}'

To fetch the MariaDB and MongoDB copies by their shared primary key:

    curl -i http://127.0.0.1:8081/api/records/demo-001

POST returns 201, GET returns 200 with a `mariadb` object and a `mongodb` object. Use a different ID for each POST; a duplicate returns 409. The automated checks can be rerun with `bash verify-api.sh`.

See [README-databases.md](README-databases.md) for the database setup details, account settings, restart instructions, and limitations of writing to two independent stores.
