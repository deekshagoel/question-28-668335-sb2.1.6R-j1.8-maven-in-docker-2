package org.codejudge.sb;

import java.util.UUID;
import org.bson.Document;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.test.context.junit4.SpringRunner;
import static org.junit.Assert.*;

/** Explicit integration check: mvn -Dtest=DatabaseConnectivityIT test. */
@RunWith(SpringRunner.class)
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.MOCK)
public class DatabaseConnectivityIT {
    @Autowired private JdbcTemplate sql;
    @Autowired private MongoTemplate mongo;

    @Test public void sqlWriteAndRead() {
        String id = UUID.randomUUID().toString();
        sql.execute("CREATE TABLE IF NOT EXISTS database_setup_probe (id VARCHAR(36) PRIMARY KEY, message VARCHAR(100) NOT NULL)");
        try {
            assertEquals(1, sql.update("INSERT INTO database_setup_probe (id, message) VALUES (?, ?)", id, "hello-sql"));
            assertEquals("hello-sql", sql.queryForObject("SELECT message FROM database_setup_probe WHERE id = ?", String.class, id));
        } finally {
            sql.update("DELETE FROM database_setup_probe WHERE id = ?", id);
        }
    }

    @Test public void mongoWriteAndRead() {
        String id = UUID.randomUUID().toString();
        Document query = new Document("_id", id);
        try {
            mongo.getCollection("database_setup_probe").insertOne(new Document("_id", id).append("message", "hello-mongo"));
            Document result = mongo.getCollection("database_setup_probe").find(query).first();
            assertNotNull(result);
            assertEquals("hello-mongo", result.getString("message"));
        } finally {
            mongo.getCollection("database_setup_probe").deleteOne(query);
        }
    }
}
