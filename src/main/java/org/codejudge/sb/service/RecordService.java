package org.codejudge.sb.service;

import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.annotation.PostConstruct;
import org.bson.Document;
import org.codejudge.sb.model.RecordPayload;
import org.springframework.data.mongodb.core.MongoTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class RecordService {
    private final JdbcTemplate sql;
    private final MongoTemplate mongo;

    public RecordService(JdbcTemplate sql, MongoTemplate mongo) {
        this.sql = sql;
        this.mongo = mongo;
    }

    @PostConstruct
    public void initializeTable() {
        sql.execute("CREATE TABLE IF NOT EXISTS dual_records (id VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin PRIMARY KEY, name VARCHAR(100) NOT NULL, message VARCHAR(500) NOT NULL) CHARACTER SET utf8mb4");
    }

    // This transaction rolls back SQL when the Mongo write fails. It does not
    // create a distributed transaction: a later SQL commit failure can leave
    // the Mongo copy present. GET detects a missing copy and returns 409.
    @Transactional
    public void create(RecordPayload record) {
        sql.update("INSERT INTO dual_records (id, name, message) VALUES (?, ?, ?)",
                record.id, record.name, record.message);
        mongo.execute("dual_records", collection -> {
            collection.insertOne(new Document("_id", record.id)
                    .append("name", record.name).append("message", record.message));
            return null;
        });
    }

    public Map<String, Object> find(String id) {
        List<Map<String, Object>> rows = sql.queryForList(
                "SELECT id, name, message FROM dual_records WHERE id = ?", id);
        Document document = mongo.execute("dual_records", collection -> collection.find(new Document("_id", id)).first());
        if (rows.isEmpty() && document == null) {
            throw new ResponseStatusException(HttpStatus.NOT_FOUND, "Record not found");
        }
        if (rows.isEmpty() || document == null) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Record exists in only one database");
        }
        Map<String, Object> mongoRecord = new LinkedHashMap<>();
        mongoRecord.put("id", document.getString("_id"));
        mongoRecord.put("name", document.getString("name"));
        mongoRecord.put("message", document.getString("message"));
        if (!rows.get(0).equals(mongoRecord)) {
            throw new ResponseStatusException(HttpStatus.CONFLICT, "Database copies differ");
        }
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", id);
        response.put("mariadb", rows.get(0));
        response.put("mongodb", mongoRecord);
        return response;
    }
}
