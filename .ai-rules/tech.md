---
title: Technology Stack
description: "Defines the languages, frameworks, tools, and infrastructure used in this project."
inclusion: always
---

# dokku-temporal - Technology Stack

## Language

- **Bash** (primary) -- All Dokku plugins are shell scripts executed by the plugn system

## Runtime Dependencies

- **Docker** -- Container runtime for running Temporal server (`$DOCKER_BIN`)
- **Dokku** >= 0.30.0 -- PaaS platform providing the plugin infrastructure
- **Remote PostgreSQL (Supabase)** -- No local dokku-postgres dependency; Temporal connects to an external Supabase PostgreSQL instance via connection parameters

## Docker Images

| Image | Purpose | Default Version |
|---|---|---|
| `temporalio/auto-setup` | Temporal server with automatic schema setup (initial creation) | 1.25.2 |
| `temporalio/server` | Production Temporal server (after initial setup) | 1.25.2 |
| `temporalio/ui` | Temporal Web UI | 2.32.0 |
| `dokku/ambassador` | Port exposure proxy (Dokku standard) | 0.8.2 |
| `dokku/wait` | Container readiness check (Dokku standard) | 0.9.3 |

## Temporal Server

- **gRPC Frontend Port**: 7233 (default)
- **Web UI Port**: 8233 (default)
- **Database Backend**: Remote PostgreSQL (Supabase, via connection parameters)
- **Dynamic Config**: YAML file mounted into the container

## PostgreSQL Configuration Strategy (Supabase Remote)

Temporal 连接外部 Supabase PostgreSQL，需要创建两个专用数据库：
- `temporal` — 主数据库（workflow state）
- `temporal_visibility` — 可见性数据库（search & list）

配置方式通过 `temporal:set` 命令注入：
```bash
dokku temporal:set <service> POSTGRES_HOST db.xxxx.supabase.co
dokku temporal:set <service> POSTGRES_PORT 5432
dokku temporal:set <service> POSTGRES_USER postgres
dokku temporal:set <service> POSTGRES_PWD <password>
dokku temporal:set <service> POSTGRES_DB temporal
dokku temporal:set <service> POSTGRES_DB_VISIBILITY temporal_visibility
dokku temporal:set <service> POSTGRES_TLS true
```

或一次性通过 DATABASE_URL 方式：
```bash
dokku temporal:set <service> DATABASE_URL "postgresql://postgres:<pwd>@db.xxxx.supabase.co:5432/temporal?sslmode=require"
```

## Key Temporal Environment Variables (Server-Side)

```
DB=postgres12
DB_PORT=5432
POSTGRES_USER=<from config>
POSTGRES_PWD=<from config>
POSTGRES_SEEDS=<supabase-host>
POSTGRES_TLS=true
POSTGRES_TLS_DISABLE_HOST_VERIFICATION=true
DBNAME=temporal
VISIBILITY_DBNAME=temporal_visibility
SERVICES=frontend
DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/dynamic_config.yaml
DEFAULT_NAMESPACE=default
```

## Conventions

- Follow the official Dokku service plugin pattern (same as dokku-postgres, dokku-redis)
- Use `$DOCKER_BIN` instead of hardcoded `docker` command
- All scripts must be executable and start with `#!/usr/bin/env bash`
- Use `set -eo pipefail` and `[[ $DOKKU_TRACE ]] && set -x` for debugging
- Container names follow the pattern `dokku.temporal.<service-name>`
- Data stored under `$DOKKU_LIB_ROOT/services/temporal/<service-name>/`

## Testing

- Manual testing against a Dokku instance
- Verify with `dokku temporal:create test && dokku temporal:info test`
