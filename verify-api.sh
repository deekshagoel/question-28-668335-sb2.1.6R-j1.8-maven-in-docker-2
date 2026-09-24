#!/usr/bin/env bash
set -euo pipefail
base=${API_BASE_URL:-http://127.0.0.1:8081}
id=verify-$(date +%s)-$RANDOM
result_dir=$(mktemp -d /tmp/dual-api-check.XXXXXX)
check() {
  local expected=$1; shift
  local code
  code=$(curl --silent --show-error --max-time 20 -o "$result_dir/response.json" -w '%{http_code}' "$@")
  if [[ $code != $expected ]]; then
    echo "FAIL: expected HTTP $expected, received $code"
    cat "$result_dir/response.json"
    exit 1
  fi
  echo "PASS: HTTP $code"
  cat "$result_dir/response.json"
  echo
}
body="{\"id\":\"$id\",\"name\":\"Deeksha\",\"message\":\"Hello from both databases\"}"
check 201 -X POST "$base/api/records" -H 'Content-Type: application/json' -d "$body"
check 200 "$base/api/records/$id"
perl -MJSON::PP -e '
  my ($file,$id)=@ARGV;
  open my $fh, "<", $file or die $!;
  local $/; my $data=decode_json(<$fh>);
  for my $store (qw(mariadb mongodb)) {
    die "ID mismatch" unless $data->{$store}{id} eq $id;
    die "Name mismatch" unless $data->{$store}{name} eq "Deeksha";
    die "Message mismatch" unless $data->{$store}{message} eq "Hello from both databases";
  }
  print "PASS: both database copies equal the submitted data\n";
' "$result_dir/response.json" "$id"
check 409 -X POST "$base/api/records" -H 'Content-Type: application/json' -d "$body"
check 404 "$base/api/records/missing-$id"
check 400 -X POST "$base/api/records" -H 'Content-Type: application/json' -d '{"id":"bad id","name":"","message":"test"}'
hex_id=$(printf '%012x%012x' "$(date +%s)" "$RANDOM")
check 201 -X POST "$base/api/records" -H 'Content-Type: application/json' -d "{\"id\":\"$hex_id\",\"name\":\"Hex ID test\",\"message\":\"Stored as a string in both databases\"}"
check 200 "$base/api/records/$hex_id"
echo "All API checks passed. Sample record: $id"
echo "Responses saved in $result_dir"
