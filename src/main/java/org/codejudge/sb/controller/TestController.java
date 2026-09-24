package org.codejudge.sb.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class TestController {

    @GetMapping("/test/2")
    public String testTwo() {
        return "Test 2";
    }
}
