---
title: 安全策略
description: "定义插件的安全设计原则、网络隔离方案和凭据保护措施。"
inclusion: always
---

# dokku-temporal - 安全策略

## 核心原则

**默认安全，最小暴露。** 所有端口默认仅内网可访问，外部访问需显式授权。

## 网络安全

### gRPC 端口（7233）

- **默认不暴露到宿主机**，仅通过 Docker 内部网络供链接的应用访问
- `temporal:expose` 默认绑定 `127.0.0.1:7233`，仅本机可达
- 需要公网暴露时必须显式指定：`temporal:expose <service> --public 7233`
- 链接的 Dokku 应用通过容器名 `dokku.temporal.<service>` 内网直连

### Web UI 端口（8233）

- **默认不启动 UI 容器**，通过 `temporal:ui-enable <service>` 手动开启
- UI 启用后仅绑定 `127.0.0.1:8233`
- 访问方式：SSH 隧道 `ssh -L 8233:localhost:8233 <dokku-server>`
- **Temporal UI 无内置认证**，绝不暴露到公网

### expose 命令安全

```bash
# 安全：绑定到 127.0.0.1（默认行为）
dokku temporal:expose main 7233 8233

# 危险：绑定到 0.0.0.0（需显式 --public 标志）
dokku temporal:expose main --public 7233 8233
# 执行前会输出警告：
# WARNING: Exposing Temporal ports to public network.
# Temporal has NO built-in authentication. Proceed? [y/N]
```

## 凭据保护

### PostgreSQL 密码

- 存储位置：`$DOKKU_LIB_ROOT/services/temporal/<service>/POSTGRES_PWD`
- 文件权限：`0600`（仅 dokku 用户可读写）
- `temporal:info` 输出中密码显示为 `****`（脱敏）
- `temporal:info --show-password` 显示明文（需确认）

### DATABASE_URL

- 存储位置：`$DOKKU_LIB_ROOT/services/temporal/<service>/DATABASE_URL`
- 同样 `0600` 权限
- info 输出中密码部分脱敏

### 服务目录权限

```bash
# 创建服务时设置目录权限
chmod 700 "$SERVICE_ROOT"
chown dokku:dokku "$SERVICE_ROOT"

# 凭据文件权限
chmod 600 "$SERVICE_ROOT/POSTGRES_PWD"
chmod 600 "$SERVICE_ROOT/POSTGRES_HOST"
chmod 600 "$SERVICE_ROOT/DATABASE_URL"
```

## Docker 容器安全

- 容器以非 root 用户运行（Temporal 镜像默认行为）
- 使用 `--restart on-failure:5` 限制重启次数，防止崩溃循环
- 不挂载宿主机敏感目录
- 仅挂载 `dynamicconfig/` 目录（只读：`-v ...:.../:ro`）

## Supabase 连接安全

- **必须启用 TLS**：`POSTGRES_TLS=true`（Supabase 强制要求）
- 建议在 Supabase 中为 Temporal 创建专用数据库用户，仅授权访问 `temporal` 和 `temporal_visibility` 两个数据库
- 建议配置 Supabase 网络限制，仅允许 Dokku 服务器 IP 连接

### Supabase 推荐配置

```sql
-- 在 Supabase SQL Editor 中执行
-- 1. 创建专用用户
CREATE USER temporal_user WITH PASSWORD 'strong-password';

-- 2. 创建专用数据库
CREATE DATABASE temporal OWNER temporal_user;
CREATE DATABASE temporal_visibility OWNER temporal_user;

-- 3. 限制权限（temporal_user 只能访问这两个库）
REVOKE ALL ON DATABASE postgres FROM temporal_user;
```

## 安全检查清单

部署前确认：

- [ ] gRPC 端口未暴露到公网（`ss -tlnp | grep 7233` 应为空或仅 127.0.0.1）
- [ ] Web UI 未暴露到公网（`ss -tlnp | grep 8233` 应为空或仅 127.0.0.1）
- [ ] PostgreSQL 使用 TLS 连接（`POSTGRES_TLS=true`）
- [ ] 凭据文件权限为 600（`ls -la $DOKKU_LIB_ROOT/services/temporal/*/POSTGRES_PWD`）
- [ ] Supabase 使用专用数据库用户（非 postgres 超级用户）
- [ ] Supabase 网络策略限制了源 IP
