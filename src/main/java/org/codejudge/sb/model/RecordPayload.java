package org.codejudge.sb.model;

import javax.validation.constraints.NotBlank;
import javax.validation.constraints.Pattern;
import javax.validation.constraints.Size;

public class RecordPayload {
    @NotBlank @Size(max = 64) @Pattern(regexp = "[A-Za-z0-9_-]+")
    public String id;
    @NotBlank @Size(max = 100)
    public String name;
    @NotBlank @Size(max = 500)
    public String message;
}
