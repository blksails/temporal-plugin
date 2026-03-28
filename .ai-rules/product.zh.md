---
title: 产品愿景
description: "定义项目的核心目标、目标用户和主要功能。"
inclusion: always
---

# dokku-temporal - 产品愿景

## 目标

一个 Dokku 插件，用于部署和管理共享的 Temporal Server 实例，使任何 Dokku 部署的应用都能连接并使用 Temporal 作为工作流编排引擎。遵循 Dokku 官方服务插件模式（与 dokku-postgres、dokku-redis 等一致）。

## 问题陈述

BlackSail 项目的应用需要 Temporal 来执行持久化工作流（如后台任务、长时间运行的流程、定时任务）。如果没有这个插件，每次部署都需要手动配置 Temporal、Docker 网络和环境变量。本插件将这些全部自动化为标准的 Dokku 命令。

## 目标用户

- 将 BlackSail 应用部署到 Dokku 服务器的运维工程师
- 需要在 Dokku 应用中使用 Temporal 工作流能力的开发者

## 核心功能

1. **服务生命周期管理** -- 通过 `dokku temporal:create`、`dokku temporal:destroy` 等命令创建、销毁、启动、停止和重启 Temporal 服务实例。
2. **应用链接** -- 通过 `dokku temporal:link <service> <app>` 将 Temporal 链接到 Dokku 应用，自动注入 `TEMPORAL_ADDRESS` 和 `TEMPORAL_NAMESPACE` 环境变量。
3. **持久化存储** -- Temporal 状态通过远程 Supabase PostgreSQL 数据库实现跨容器重启的持久化。
4. **Web UI 访问** -- 暴露 Temporal Web UI 用于工作流监控和调试。
5. **命名空间** -- 启动时确保 `default` 命名空间；额外命名空间在容器内用 `tctl` 管理。
6. **配置管理** -- 允许自定义 Temporal 动态配置、gRPC 端口和每个服务实例的其他设置。

## 非目标

- 本插件**不替代**生产级 Temporal Cloud 部署，适用于自托管 Dokku 环境。
- 本插件**不管理** Temporal Worker，Worker 在链接的应用内运行。

## 链接到应用时注入的环境变量

| 变量 | 示例值 | 说明 |
|---|---|---|
| `TEMPORAL_URL` | `temporal://dokku-temporal-main:7233` | 完整服务 URL（Dokku 约定） |
| `TEMPORAL_ADDRESS` | `dokku-temporal-main:7233` | Temporal SDK 客户端使用的 gRPC 端点 |
| `TEMPORAL_NAMESPACE` | `default` | 链接应用使用的 Temporal 命名空间 |

## 命令参考

```
temporal:create <service>          创建 Temporal 服务
temporal:destroy <service>         销毁 Temporal 服务
temporal:link <service> <app>      将 Temporal 链接到应用
temporal:unlink <service> <app>    取消 Temporal 与应用的链接
temporal:info <service>            显示服务信息
temporal:start <service>           启动服务
temporal:stop <service>            停止服务
temporal:restart <service>         重启服务
temporal:expose <service> [ports]  暴露端口到宿主机
temporal:unexpose <service>        取消暴露端口
temporal:list                      列出所有 Temporal 服务
temporal:set <service> <key> <val> 设置服务属性
```

## 典型使用流程

```bash
# 1. 创建服务（此时不启动）
dokku temporal:create main

# 2. 配置 Supabase PostgreSQL 连接
dokku temporal:set main POSTGRES_HOST db.xxxx.supabase.co
dokku temporal:set main POSTGRES_PORT 5432
dokku temporal:set main POSTGRES_USER postgres
dokku temporal:set main POSTGRES_PWD your-password
dokku temporal:set main POSTGRES_TLS true

# 3. 启动服务（auto-setup 镜像自动建表）
dokku temporal:start main

# 4. 链接到应用（自动注入环境变量并重启应用）
dokku temporal:link main my-worker-app
```
