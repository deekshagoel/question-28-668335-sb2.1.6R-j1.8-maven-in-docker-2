package org.codejudge.sb.controller;

import java.net.URI;
import java.util.Arrays;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import javax.validation.Valid;
import org.codejudge.sb.model.RecordPayload;
import org.codejudge.sb.service.RecordService;
import org.springframework.dao.DataAccessException;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/records")
public class RecordCreateController {
    private final RecordService records;

    public RecordCreateController(RecordService records) {
        this.records = records;
    }

    @PostMapping
    public ResponseEntity<Map<String, Object>> create(@Valid @RequestBody RecordPayload record) {
        records.create(record);
        Map<String, Object> response = new LinkedHashMap<>();
        response.put("id", record.id);
        response.put("storedIn", Arrays.asList("mariadb", "mongodb"));
        return ResponseEntity.created(URI.create("/api/records/" + record.id)).body(response);
    }

    @ExceptionHandler(DuplicateKeyException.class)
    public ResponseEntity<Map<String, String>> duplicate(DuplicateKeyException error) {
        return ResponseEntity.status(HttpStatus.CONFLICT).body(Collections.singletonMap("error", "ID already exists in a database. Use GET to inspect it or choose a new ID."));
    }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> databaseError(DataAccessException error) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Collections.singletonMap("error", "Database operation failed. A partial write is possible; inspect the same ID before retrying."));
    }
}
