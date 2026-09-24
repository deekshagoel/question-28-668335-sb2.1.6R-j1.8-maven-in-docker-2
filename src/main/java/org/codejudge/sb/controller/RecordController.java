package org.codejudge.sb.controller;

import java.util.Collections;
import java.util.Map;
import org.codejudge.sb.service.RecordService;
import org.springframework.dao.DataAccessException;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/records")
public class RecordController {
    private final RecordService records;
    public RecordController(RecordService records) { this.records = records; }

    @GetMapping("/{id}")
    public Map<String, Object> find(@PathVariable String id) { return records.find(id); }

    @ExceptionHandler(DataAccessException.class)
    public ResponseEntity<Map<String, String>> databaseError(DataAccessException error) {
        return ResponseEntity.status(HttpStatus.SERVICE_UNAVAILABLE).body(Collections.singletonMap("error", "Database operation failed. A partial write is possible; inspect the same ID before retrying."));
    }
}
