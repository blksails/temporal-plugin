---
title: 技术栈
description: "定义项目使用的语言、框架、工具和基础设施。"
inclusion: always
---

# dokku-temporal - 技术栈

## 语言

- **Bash**（主要） -- 所有 Dokku 插件都是由 plugn 系统执行的 shell 脚本

## 运行时依赖

- **Docker** -- 运行 Temporal 服务的容器运行时（`$DOCKER_BIN`）
- **Dokku** >= 0.30.0 -- 提供插件基础设施的 PaaS 平台
- **远程 PostgreSQL（Supabase）** -- 无本地 dokku-postgres 依赖；Temporal 通过连接参数连接外部 Supabase PostgreSQL 实例

## Docker 镜像

| 镜像 | 用途 | 默认版本 |
|---|---|---|
| `temporalio/auto-setup` | 带自动 schema 建表的 Temporal 服务器（初始创建） | 1.25.2 |
| `temporalio/server` | 生产 Temporal 服务器（初始建表后可选切换） | 1.25.2 |
| `temporalio/ui` | Temporal Web UI | 2.32.0 |
| `dokku/ambassador` | 端口暴露代理（Dokku 标准） | 0.8.2 |
| `dokku/wait` | 容器就绪检查（Dokku 标准） | 0.9.3 |

## Temporal 服务器

- **gRPC 前端端口**：7233（默认）
- **Web UI 端口**：8233（默认）
- **数据库后端**：远程 PostgreSQL（Supabase，通过连接参数配置）
- **动态配置**：YAML 文件挂载到容器内

## PostgreSQL 配置策略（Supabase 远程）

Temporal 连接外部 Supabase PostgreSQL，需要创建两个专用数据库：
- `temporal` -- 主数据库（workflow 状态存储）
- `temporal_visibility` -- 可见性数据库（搜索与列表查询）

### 配置方式一：分字段配置（推荐）

```bash
dokku temporal:set <service> POSTGRES_HOST db.xxxx.supabase.co
dokku temporal:set <service> POSTGRES_PORT 5432
dokku temporal:set <service> POSTGRES_USER postgres
dokku temporal:set <service> POSTGRES_PWD <password>
dokku temporal:set <service> POSTGRES_DB temporal
dokku temporal:set <service> POSTGRES_DB_VISIBILITY temporal_visibility
dokku temporal:set <service> POSTGRES_TLS true
```

### 配置方式二：DATABASE_URL（一行搞定）

```bash
dokku temporal:set <service> DATABASE_URL "postgresql://postgres:<pwd>@db.xxxx.supabase.co:5432/temporal?sslmode=require"
```

使用 DATABASE_URL 时，插件自动解析其中的 host/port/user/password/dbname。
可见性数据库名默认为 `<dbname>_visibility`，也可通过 `POSTGRES_DB_VISIBILITY` 单独覆盖。

## Temporal 容器环境变量（服务端）

```
DB=postgres12
DB_PORT=5432
POSTGRES_USER=<来自配置>
POSTGRES_PWD=<来自配置>
POSTGRES_SEEDS=<supabase-host>
POSTGRES_TLS=true
POSTGRES_TLS_DISABLE_HOST_VERIFICATION=true
DBNAME=temporal
VISIBILITY_DBNAME=temporal_visibility
SERVICES=frontend
DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/dynamic_config.yaml
DEFAULT_NAMESPACE=default
```

## 开发约定

- 遵循 Dokku 官方服务插件模式（与 dokku-postgres、dokku-redis 一致）
- 使用 `$DOCKER_BIN` 而非硬编码的 `docker` 命令
- 所有脚本必须可执行，以 `#!/usr/bin/env bash` 开头
- 使用 `set -eo pipefail` 和 `[[ $DOKKU_TRACE ]] && set -x` 支持调试
- 容器名遵循 `dokku.temporal.<service-name>` 模式
- 数据存储于 `$DOKKU_LIB_ROOT/services/temporal/<service-name>/`

## 测试

- 在 Dokku 实例上手动测试
- 验证命令：`dokku temporal:create test && dokku temporal:info test`
