# dokku-temporal

Dokku 的 Temporal 工作流服务插件，支持连接远程 Supabase PostgreSQL 数据库。

---

## 目录

- [安装](#安装)
- [快速开始](#快速开始)
- [Supabase PostgreSQL 准备](#supabase-postgresql-准备)
- [命令参考](#命令参考)
- [环境变量说明](#环境变量说明)
- [安全注意事项](#安全注意事项)
- [故障排查指南](#故障排查指南)

---

## 安装

在 Dokku 服务器上执行：

```bash
dokku plugin:install https://github.com/your-org/dokku-temporal.git temporal
```

安装时会自动拉取以下 Docker 镜像：
- `temporalio/auto-setup:1.25.2`（Temporal 服务，自动建表）
- `temporalio/ui:2.32.0`（Web UI，可选）
- `dokku/ambassador:0.8.2`（端口代理）
- `dokku/wait:0.9.3`（就绪检查）

---

## 快速开始

### 1. 准备 Supabase PostgreSQL 数据库

参见 [Supabase PostgreSQL 准备](#supabase-postgresql-准备) 章节。

### 2. 创建 Temporal 服务

```bash
dokku temporal:create main
```

### 3. 配置 PostgreSQL 连接

```bash
# 方式 A：逐字段配置
dokku temporal:set main POSTGRES_HOST db.xxxxxxxxxxxxxxxx.supabase.co
dokku temporal:set main POSTGRES_PORT 5432
dokku temporal:set main POSTGRES_USER temporal_user
dokku temporal:set main POSTGRES_PWD your-strong-password
dokku temporal:set main POSTGRES_DB temporal
dokku temporal:set main POSTGRES_TLS true

# 方式 B：使用 DATABASE_URL（一次性配置）
dokku temporal:set main DATABASE_URL "postgres://temporal_user:your-password@db.xxxxxxxxxxxxxxxx.supabase.co:5432/temporal?sslmode=require"
```

### 4. 启动服务

```bash
dokku temporal:start main
```

启动完成后会自动进行健康检查，确认 gRPC 7233 端口就绪。

### 5. 链接到应用

```bash
dokku temporal:link main your-app
```

链接后应用自动注入环境变量：
- `TEMPORAL_URL=temporal://dokku.temporal.main:7233`
- `TEMPORAL_ADDRESS=dokku.temporal.main:7233`
- `TEMPORAL_NAMESPACE=default`

### 6. 查看服务信息

```bash
dokku temporal:info main
```

---

## Supabase PostgreSQL 准备

Temporal 需要两个数据库：主数据库和 Visibility 数据库。请在 Supabase SQL Editor 中执行以下 SQL：

```sql
-- 创建专用用户
CREATE USER temporal_user WITH PASSWORD 'your-strong-password';

-- 创建主数据库
CREATE DATABASE temporal OWNER temporal_user;

-- 创建 Visibility 数据库
CREATE DATABASE temporal_visibility OWNER temporal_user;

-- 授权
GRANT ALL PRIVILEGES ON DATABASE temporal TO temporal_user;
GRANT ALL PRIVILEGES ON DATABASE temporal_visibility TO temporal_user;

-- 如果使用 Supabase 托管实例，还需要：
-- （在 temporal 数据库中执行）
\c temporal
GRANT ALL ON SCHEMA public TO temporal_user;

-- （在 temporal_visibility 数据库中执行）
\c temporal_visibility
GRANT ALL ON SCHEMA public TO temporal_user;
```

配置时对应设置：
```bash
dokku temporal:set main POSTGRES_DB temporal
# temporal_visibility 会自动由 POSTGRES_DB + "_visibility" 推断
# 或手动指定：
dokku temporal:set main POSTGRES_DB_VISIBILITY temporal_visibility
```

---

## 命令参考

### 服务管理

| 命令 | 说明 |
|------|------|
| `temporal:create <service>` | 创建 Temporal 服务 |
| `temporal:destroy <service> [--force]` | 销毁服务（需确认） |
| `temporal:start <service>` | 启动服务 |
| `temporal:stop <service>` | 停止服务 |
| `temporal:restart <service>` | 重启服务 |
| `temporal:info <service> [--show-password]` | 显示服务信息 |
| `temporal:list` | 列出所有服务 |

### 配置管理

```bash
# 设置配置项
dokku temporal:set <service> <KEY> <VALUE>

# 清除配置项
dokku temporal:set <service> <KEY>
```

支持的配置 KEY：

| KEY | 说明 |
|-----|------|
| `POSTGRES_HOST` | PostgreSQL 主机地址 |
| `POSTGRES_PORT` | PostgreSQL 端口（默认 5432） |
| `POSTGRES_USER` | PostgreSQL 用户名 |
| `POSTGRES_PWD` | PostgreSQL 密码（权限 600） |
| `POSTGRES_DB` | 主数据库名（默认 temporal） |
| `POSTGRES_DB_VISIBILITY` | Visibility 数据库名（默认 `{POSTGRES_DB}_visibility`） |
| `POSTGRES_TLS` | 是否启用 TLS（true/false，Supabase 需设为 true） |
| `DATABASE_URL` | PostgreSQL 连接 URL（权限 600） |
| `IMAGE` | Docker 镜像名（默认 temporalio/auto-setup） |
| `IMAGE_VERSION` | Docker 镜像版本（默认 1.25.2） |
| `CONFIG_OPTIONS` | 额外 docker run 参数（如资源限制） |
| `UI_ENABLED` | 启用 Web UI（true/false） |
| `UI_PORT` | Web UI 宿主机端口（默认 8233；若端口冲突可改为如 8234） |
| `AUTOSTART` | Dokku 重启后自动启动（true/false，默认 true） |

### 应用链接

```bash
# 链接应用
dokku temporal:link <service> <app> [--alias <prefix>] [--namespace <ns>]

# 取消链接
dokku temporal:unlink <service> <app>
```

链接关系记录在服务的 `LINKS` 文件中（`dokku temporal:info` 会显示摘要）。也可用 `dokku config:show <app> | grep TEMPORAL` 确认环境变量。

### 端口暴露

```bash
# 暴露到本地（127.0.0.1）
dokku temporal:expose <service> [port]

# 暴露到公网（危险，需确认）
dokku temporal:expose <service> --public [port]

# 取消暴露
dokku temporal:unexpose <service>
```

命名空间、日志与 `tctl`：请在服务器上使用 Docker 直接操作容器，例如 `docker logs dokku.temporal.<service>`、`docker exec -it dokku.temporal.<service> tctl ...`。

### 版本升级

```bash
# 切换到新版本（重启后生效）
dokku temporal:set <service> IMAGE_VERSION 1.26.0
dokku temporal:restart <service>

# 从 auto-setup 切换到 server 镜像
dokku temporal:set <service> IMAGE temporalio/server
dokku temporal:set <service> IMAGE_VERSION 1.25.2
dokku temporal:restart <service>
```

---

## 环境变量说明

链接应用后注入的环境变量：

| 变量 | 示例值 | 说明 |
|------|--------|------|
| `TEMPORAL_URL` | `temporal://dokku.temporal.main:7233` | Temporal 连接 URL |
| `TEMPORAL_ADDRESS` | `dokku.temporal.main:7233` | Temporal gRPC 地址 |
| `TEMPORAL_NAMESPACE` | `default` | 使用的命名空间 |

应用代码示例（Go）：
```go
temporalClient, err := client.Dial(client.Options{
    HostPort:  os.Getenv("TEMPORAL_ADDRESS"),
    Namespace: os.Getenv("TEMPORAL_NAMESPACE"),
})
```

应用代码示例（Python）：
```python
import os
from temporalio.client import Client

client = await Client.connect(
    os.environ["TEMPORAL_ADDRESS"],
    namespace=os.environ["TEMPORAL_NAMESPACE"],
)
```

---

## 安全注意事项

1. **密码文件权限**：`POSTGRES_PWD` 和 `DATABASE_URL` 文件权限设为 `600`，仅 root 可读。
2. **服务目录权限**：`/var/lib/dokku/services/temporal/<service>/` 权限设为 `700`。
3. **UI 仅绑定本地**：Web UI 默认绑定 `127.0.0.1:8233`，通过 SSH 隧道访问：
   ```bash
   ssh -L 8233:localhost:8233 user@your-dokku-server
   # 然后浏览器访问 http://localhost:8233
   ```
4. **端口默认不暴露**：gRPC 端口 7233 默认不对外暴露，应用通过 Docker 网络内部访问。
5. **公网暴露警告**：使用 `--public` 标志时会显示安全警告并要求确认。
6. **info 命令脱敏**：`temporal:info` 默认用 `****` 遮蔽密码，使用 `--show-password` 显示明文。
7. **TLS 连接**：连接 Supabase 时务必设置 `POSTGRES_TLS=true`。

---

## 故障排查指南

### 服务启动超时

```
Temporal did not become ready within 60s
```

排查步骤：

```bash
# 1. 查看容器日志
docker logs --tail 50 dokku.temporal.main

# 2. 检查 PostgreSQL 连接
dokku temporal:info main

# 3. 手动测试 PostgreSQL 连接（在 Dokku 服务器上）
psql "postgres://temporal_user:password@db.xxx.supabase.co:5432/temporal?sslmode=require" -c "SELECT 1"
```

常见原因：
- PostgreSQL 主机或密码配置错误
- Supabase 需要 TLS（`POSTGRES_TLS=true`）
- 数据库或用户不存在
- Supabase 项目已暂停（免费套餐 7 天不活动自动暂停）

### 容器立即退出

```bash
# 查看完整日志
docker logs dokku.temporal.main

# 检查容器状态
docker inspect dokku.temporal.main | grep -A5 '"State"'
```

### 应用无法连接 Temporal

```bash
# 确认环境变量注入
dokku config:show your-app | grep TEMPORAL

# 确认 Docker 网络
docker network inspect dokku | grep -A3 "temporal"
```

### auto-setup 重复建表警告

使用 `temporalio/auto-setup` 镜像时，每次启动会检查并创建缺失的表结构，这是正常行为。若需避免，可切换到 `temporalio/server` 镜像（需提前手动运行 schema 迁移）。

### Dokku 重启后服务未自动启动

检查 AUTOSTART 设置：

```bash
# 查看当前设置
dokku temporal:info main | grep AUTOSTART

# 启用自动启动
dokku temporal:set main AUTOSTART true
```

如果 AUTOSTART=true 但服务仍未启动，查看 Dokku 启动日志：

```bash
journalctl -u dokku --since "10 minutes ago" | grep -i temporal
```

---

## 许可证

MIT License。详见 [LICENSE.txt](LICENSE.txt)。
