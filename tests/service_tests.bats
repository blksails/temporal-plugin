#!/usr/bin/env bats
# tests/service_tests.bats - BATS test suite for dokku-temporal plugin
# Run: bats tests/service_tests.bats

load "helpers"

# ===========================================================================
# subcommands/create
# ===========================================================================

@test "create: creates service directory with correct permissions" {
  run bash "$PLUGIN_DIR/subcommands/create" "testsvc"
  [ "$status" -eq 0 ]

  local svc_root="$PLUGIN_BASE_PATH/testsvc"
  [ -d "$svc_root" ]

  # Directory must be 700
  local perms
  perms="$(stat -f '%Lp' "$svc_root" 2>/dev/null || stat -c '%a' "$svc_root" 2>/dev/null)"
  [ "$perms" = "700" ]
}

@test "create: writes required default files" {
  run bash "$PLUGIN_DIR/subcommands/create" "testsvc"
  [ "$status" -eq 0 ]

  local svc_root="$PLUGIN_BASE_PATH/testsvc"
  [ -f "$svc_root/IMAGE" ]
  [ -f "$svc_root/IMAGE_VERSION" ]
  [ -f "$svc_root/PORT" ]
  [ -f "$svc_root/UI_PORT" ]
  [ -f "$svc_root/LINKS" ]
}

@test "create: PORT file contains 7233" {
  run bash "$PLUGIN_DIR/subcommands/create" "testsvc"
  [ "$status" -eq 0 ]
  local val
  val="$(cat "$PLUGIN_BASE_PATH/testsvc/PORT")"
  [ "$val" = "7233" ]
}

@test "create: rejects invalid service name with uppercase" {
  run bash "$PLUGIN_DIR/subcommands/create" "TestSvc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid service name"* ]] || [[ "$output" == *"Invalid"* ]]
}

@test "create: rejects service name with special characters" {
  run bash "$PLUGIN_DIR/subcommands/create" "test_svc!"
  [ "$status" -ne 0 ]
}

@test "create: rejects empty service name" {
  run bash "$PLUGIN_DIR/subcommands/create" ""
  [ "$status" -ne 0 ]
  [[ "$output" == *"service name"* ]]
}

@test "create: rejects service name longer than 32 characters" {
  run bash "$PLUGIN_DIR/subcommands/create" "a-very-long-service-name-that-exceeds-32"
  [ "$status" -ne 0 ]
}

@test "create: rejects duplicate creation" {
  bash "$PLUGIN_DIR/subcommands/create" "testsvc"
  run bash "$PLUGIN_DIR/subcommands/create" "testsvc"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

# ===========================================================================
# subcommands/set
# ===========================================================================

@test "set: writes key value to service directory file" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "POSTGRES_HOST" "db.example.supabase.co"
  [ "$status" -eq 0 ]
  local val
  val="$(cat "$PLUGIN_BASE_PATH/testsvc/POSTGRES_HOST")"
  [ "$val" = "db.example.supabase.co" ]
}

@test "set: credential file POSTGRES_PWD gets chmod 600" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "POSTGRES_PWD" "supersecret"
  [ "$status" -eq 0 ]

  local perms
  perms="$(stat -f '%Lp' "$PLUGIN_BASE_PATH/testsvc/POSTGRES_PWD" 2>/dev/null \
        || stat -c '%a' "$PLUGIN_BASE_PATH/testsvc/POSTGRES_PWD" 2>/dev/null)"
  [ "$perms" = "600" ]
}

@test "set: credential file DATABASE_URL gets chmod 600" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "DATABASE_URL" "postgres://u:p@host:5432/db"
  [ "$status" -eq 0 ]

  local perms
  perms="$(stat -f '%Lp' "$PLUGIN_BASE_PATH/testsvc/DATABASE_URL" 2>/dev/null \
        || stat -c '%a' "$PLUGIN_BASE_PATH/testsvc/DATABASE_URL" 2>/dev/null)"
  [ "$perms" = "600" ]
}

@test "set: rejects invalid key" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "EVIL_KEY" "value"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid key"* ]]
}

@test "set: UI_PORT accepts valid port" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "UI_PORT" "8234"
  [ "$status" -eq 0 ]
  [ "$(cat "$PLUGIN_BASE_PATH/testsvc/UI_PORT")" = "8234" ]
}

@test "set: UI_PORT rejects port below 1024" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "UI_PORT" "80"
  [ "$status" -ne 0 ]
  [[ "$output" == *"Invalid UI_PORT"* ]] || [[ "$output" == *"1024"* ]]
}

@test "set: unsets a key when value is empty" {
  create_service_fixture "testsvc"
  bash "$PLUGIN_DIR/subcommands/set" "testsvc" "POSTGRES_HOST" "db.example.com"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "POSTGRES_HOST" ""
  [ "$status" -eq 0 ]
  [ ! -f "$PLUGIN_BASE_PATH/testsvc/POSTGRES_HOST" ]
}

@test "set: masks credential in summary output" {
  create_service_fixture "testsvc"
  run bash "$PLUGIN_DIR/subcommands/set" "testsvc" "POSTGRES_PWD" "mysecret"
  [ "$status" -eq 0 ]
  # Summary should not show the actual password
  [[ "$output" != *"mysecret"* ]]
  [[ "$output" == *"****"* ]]
}

# ===========================================================================
# subcommands/list
# ===========================================================================

@test "list: outputs header row" {
  create_service_fixture "alpha"
  run bash "$PLUGIN_DIR/subcommands/list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"NAME"* ]]
  [[ "$output" == *"STATUS"* ]]
  [[ "$output" == *"VERSION"* ]]
}

@test "list: includes created service in output" {
  create_service_fixture "mysvc"
  run bash "$PLUGIN_DIR/subcommands/list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"mysvc"* ]]
}

@test "list: shows 'stopped' status when container is not running" {
  create_service_fixture "mysvc"
  run bash "$PLUGIN_DIR/subcommands/list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopped"* ]]
}

@test "list: prints message when no services exist" {
  run bash "$PLUGIN_DIR/subcommands/list"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no"* ]] || [[ "$output" == *"No"* ]]
}

# ===========================================================================
# subcommands/destroy
# ===========================================================================

@test "destroy --force: removes service directory" {
  create_service_fixture "delsvc"
  run bash "$PLUGIN_DIR/subcommands/destroy" "delsvc" "--force"
  [ "$status" -eq 0 ]
  [ ! -d "$PLUGIN_BASE_PATH/delsvc" ]
}

@test "destroy --force: outputs confirmation message" {
  create_service_fixture "delsvc"
  run bash "$PLUGIN_DIR/subcommands/destroy" "delsvc" "--force"
  [ "$status" -eq 0 ]
  [[ "$output" == *"destroyed"* ]] || [[ "$output" == *"Destroy"* ]]
}

@test "destroy: fails without --force when stdin is not a tty" {
  create_service_fixture "delsvc"
  # Pipe empty input to simulate non-interactive — confirmation will fail
  run bash -c "echo 'wrongname' | bash '$PLUGIN_DIR/subcommands/destroy' delsvc"
  [ "$status" -ne 0 ]
}

# ===========================================================================
# subcommands/info
# ===========================================================================

@test "info: masks password by default" {
  create_service_fixture "infosvc"
  echo "supersecret" > "$PLUGIN_BASE_PATH/infosvc/POSTGRES_PWD"
  chmod 600 "$PLUGIN_BASE_PATH/infosvc/POSTGRES_PWD"

  run bash "$PLUGIN_DIR/subcommands/info" "infosvc"
  [ "$status" -eq 0 ]
  [[ "$output" != *"supersecret"* ]]
  [[ "$output" == *"****"* ]]
}

@test "info --show-password: reveals password" {
  create_service_fixture "infosvc"
  echo "supersecret" > "$PLUGIN_BASE_PATH/infosvc/POSTGRES_PWD"
  chmod 600 "$PLUGIN_BASE_PATH/infosvc/POSTGRES_PWD"

  run bash "$PLUGIN_DIR/subcommands/info" "infosvc" "--show-password"
  [ "$status" -eq 0 ]
  [[ "$output" == *"supersecret"* ]]
}

@test "info: shows service name in output" {
  create_service_fixture "infosvc"
  run bash "$PLUGIN_DIR/subcommands/info" "infosvc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"infosvc"* ]]
}

@test "info: shows stopped status when container not running" {
  create_service_fixture "infosvc"
  run bash "$PLUGIN_DIR/subcommands/info" "infosvc"
  [ "$status" -eq 0 ]
  [[ "$output" == *"stopped"* ]]
}

# ===========================================================================
# verify_service_name (via common-functions)
# ===========================================================================

@test "verify_service_name: accepts valid lowercase name" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'my-service'
    echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "verify_service_name: accepts alphanumeric name" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'svc123'
    echo 'ok'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ok"* ]]
}

@test "verify_service_name: rejects name with uppercase" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'MySvc'
  "
  [ "$status" -ne 0 ]
}

@test "verify_service_name: rejects name with underscore" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'my_svc'
  "
  [ "$status" -ne 0 ]
}

@test "verify_service_name: rejects name with spaces" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'my svc'
  "
  [ "$status" -ne 0 ]
}

@test "verify_service_name: rejects empty name" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name ''
  "
  [ "$status" -ne 0 ]
}

@test "verify_service_name: rejects name longer than 32 chars" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name 'abcdefghijklmnopqrstuvwxyz-1234567'
  "
  [ "$status" -ne 0 ]
}

@test "verify_service_name: rejects name starting with hyphen" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    verify_service_name '-bad'
  "
  [ "$status" -ne 0 ]
}

# ===========================================================================
# parse_database_url (via common-functions)
# ===========================================================================

@test "parse_database_url: parses valid postgres URL" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    parse_database_url 'postgres://myuser:mypass@db.example.com:5432/mydb'
    echo \"HOST=\$PG_HOST USER=\$PG_USER PWD=\$PG_PWD PORT=\$PG_PORT DB=\$PG_DB\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"HOST=db.example.com"* ]]
  [[ "$output" == *"USER=myuser"* ]]
  [[ "$output" == *"PORT=5432"* ]]
  [[ "$output" == *"DB=mydb"* ]]
}

@test "parse_database_url: rejects empty URL" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    parse_database_url ''
  "
  [ "$status" -ne 0 ]
}

@test "parse_database_url: rejects non-postgres URL" {
  run bash -c "
    source '$PLUGIN_DIR/config'
    source '$PLUGIN_DIR/common-functions'
    parse_database_url 'mysql://user:pass@host/db'
  "
  [ "$status" -ne 0 ]
}

# ===========================================================================
# subcommands/expose
# ===========================================================================

@test "expose: defaults to 127.0.0.1 binding" {
  create_service_fixture "exposesvc"
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "7233"
  [ "$status" -eq 0 ]

  # Check PORT_MAP file was written with 127.0.0.1
  local port_map
  port_map="$(cat "$PLUGIN_BASE_PATH/exposesvc/PORT_MAP")"
  [[ "$port_map" == *"127.0.0.1"* ]]
}

@test "expose: PORT_MAP file gets chmod 600" {
  create_service_fixture "exposesvc"
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "7233"
  [ "$status" -eq 0 ]

  local perms
  perms="$(stat -f '%Lp' "$PLUGIN_BASE_PATH/exposesvc/PORT_MAP" 2>/dev/null \
        || stat -c '%a' "$PLUGIN_BASE_PATH/exposesvc/PORT_MAP" 2>/dev/null)"
  [ "$perms" = "600" ]
}

@test "expose: rejects port below 1024" {
  create_service_fixture "exposesvc"
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "80"
  [ "$status" -ne 0 ]
  [[ "$output" == *"1024"* ]] || [[ "$output" == *"Invalid port"* ]]
}

@test "expose: rejects port above 65535" {
  create_service_fixture "exposesvc"
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "70000"
  [ "$status" -ne 0 ]
}

@test "expose: rejects non-numeric port" {
  create_service_fixture "exposesvc"
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "abc"
  [ "$status" -ne 0 ]
}

@test "expose: UI port maps to UI_HOST_BIND, not server PORT_MAP" {
  create_service_fixture "exposesvc"
  echo "true" > "$PLUGIN_BASE_PATH/exposesvc/UI_ENABLED"
  chmod 640 "$PLUGIN_BASE_PATH/exposesvc/UI_ENABLED"

  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc"
  [ "$status" -eq 0 ]

  local port_map
  port_map="$(cat "$PLUGIN_BASE_PATH/exposesvc/PORT_MAP")"
  [[ "$port_map" == "127.0.0.1:7233:7233" ]]
  [[ "$port_map" != *"8233"* ]]

  [ -f "$PLUGIN_BASE_PATH/exposesvc/UI_HOST_BIND" ]
  [[ "$(cat "$PLUGIN_BASE_PATH/exposesvc/UI_HOST_BIND")" == "127.0.0.1" ]]
}

@test "expose: explicit 7233 only drops UI_HOST_BIND when UI enabled" {
  create_service_fixture "exposesvc"
  echo "true" > "$PLUGIN_BASE_PATH/exposesvc/UI_ENABLED"
  chmod 640 "$PLUGIN_BASE_PATH/exposesvc/UI_ENABLED"

  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "7233"
  [ "$status" -eq 0 ]
  [ ! -f "$PLUGIN_BASE_PATH/exposesvc/UI_HOST_BIND" ]
}

@test "expose: UI port never appears on server PORT_MAP when UI disabled" {
  create_service_fixture "exposesvc"
  # UI_ENABLED unset / false; user still passes 8233 (e.g. old habit) — must not map 8233:8233 on server
  run bash "$PLUGIN_DIR/subcommands/expose" "exposesvc" "7233" "8233"
  [ "$status" -eq 0 ]
  local port_map
  port_map="$(cat "$PLUGIN_BASE_PATH/exposesvc/PORT_MAP")"
  [[ "$port_map" == "127.0.0.1:7233:7233" ]]
  [[ "$port_map" != *"8233"* ]]
  [ ! -f "$PLUGIN_BASE_PATH/exposesvc/UI_HOST_BIND" ]
}

# ===========================================================================
# subcommands/link and subcommands/unlink (mock-based)
# ===========================================================================

@test "link: injects TEMPORAL_URL, TEMPORAL_ADDRESS, TEMPORAL_NAMESPACE into app config" {
  init_mock_state
  create_service_fixture "linksvc"

  # link also calls dokku temporal:start if container not running; mock handles it.
  # The mock docker inspect exits 1 so is_container_running returns false.
  # The link script then calls "dokku temporal:start linksvc" (mocked to succeed).
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  [ "$status" -eq 0 ]

  # Verify the env vars were set via mock
  local state_file="$MOCK_STATE_DIR/myapp.env"
  [ -f "$state_file" ]
  grep -q "TEMPORAL_URL=" "$state_file"
  grep -q "TEMPORAL_ADDRESS=" "$state_file"
  grep -q "TEMPORAL_NAMESPACE=" "$state_file"
}

@test "link: TEMPORAL_ADDRESS contains container name" {
  init_mock_state
  create_service_fixture "linksvc"
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  [ "$status" -eq 0 ]

  local state_file="$MOCK_STATE_DIR/myapp.env"
  grep -q "TEMPORAL_ADDRESS=dokku.temporal.linksvc:7233" "$state_file"
}

@test "link: TEMPORAL_URL uses temporal:// scheme" {
  init_mock_state
  create_service_fixture "linksvc"
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  [ "$status" -eq 0 ]

  local state_file="$MOCK_STATE_DIR/myapp.env"
  grep -q "TEMPORAL_URL=temporal://dokku.temporal.linksvc:7233" "$state_file"
}

@test "link: records app in LINKS file" {
  init_mock_state
  create_service_fixture "linksvc"
  bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  grep -qxF "myapp" "$PLUGIN_BASE_PATH/linksvc/LINKS"
}

@test "link: rejects duplicate link" {
  init_mock_state
  create_service_fixture "linksvc"
  bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  [ "$status" -ne 0 ]
  [[ "$output" == *"already linked"* ]]
}

@test "link: uses default namespace 'default' when not specified" {
  init_mock_state
  create_service_fixture "linksvc"
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --no-restart
  [ "$status" -eq 0 ]

  local state_file="$MOCK_STATE_DIR/myapp.env"
  grep -q "TEMPORAL_NAMESPACE=default" "$state_file"
}

@test "link: uses custom namespace when --namespace is specified" {
  init_mock_state
  create_service_fixture "linksvc"
  run bash "$PLUGIN_DIR/subcommands/link" "linksvc" "myapp" --namespace my-ns --no-restart
  [ "$status" -eq 0 ]

  local state_file="$MOCK_STATE_DIR/myapp.env"
  grep -q "TEMPORAL_NAMESPACE=my-ns" "$state_file"
}

@test "unlink: removes TEMPORAL vars from app config" {
  init_mock_state
  create_service_fixture "unlinksvc"
  # First link
  bash "$PLUGIN_DIR/subcommands/link" "unlinksvc" "myapp" --no-restart

  # Verify vars are set
  local state_file="$MOCK_STATE_DIR/myapp.env"
  grep -q "TEMPORAL_URL=" "$state_file"

  # Now unlink
  run bash "$PLUGIN_DIR/subcommands/unlink" "unlinksvc" "myapp" --no-restart
  [ "$status" -eq 0 ]

  # After unlink the key should be gone from state
  if [[ -f "$state_file" ]]; then
    ! grep -q "TEMPORAL_URL=temporal://dokku.temporal.unlinksvc" "$state_file"
  fi
}

@test "unlink: removes app from LINKS file" {
  init_mock_state
  create_service_fixture "unlinksvc"
  bash "$PLUGIN_DIR/subcommands/link" "unlinksvc" "myapp" --no-restart
  bash "$PLUGIN_DIR/subcommands/unlink" "unlinksvc" "myapp" --no-restart
  ! grep -qxF "myapp" "$PLUGIN_BASE_PATH/unlinksvc/LINKS"
}

@test "unlink: fails when app is not linked" {
  init_mock_state
  create_service_fixture "unlinksvc"
  run bash "$PLUGIN_DIR/subcommands/unlink" "unlinksvc" "notlinkedapp" --no-restart
  [ "$status" -ne 0 ]
  [[ "$output" == *"not linked"* ]]
}
