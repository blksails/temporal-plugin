---
title: 项目结构
description: "定义目录布局、文件命名约定和组织规则。"
inclusion: always
---

# dokku-temporal - 项目结构

## 目录布局

```
dokku-temporal/
├── .ai-rules/                    # AI 指导文件
│   ├── product.md / product.zh.md
│   ├── tech.md / tech.zh.md
│   └── structure.md / structure.zh.md
├── plugin.toml                   # 插件元数据（名称、版本、描述）
├── Dockerfile                    # 基础镜像引用（temporalio/auto-setup:1.25.2）
├── config                        # 插件配置变量（导出）
├── commands                      # 命令路由和帮助输出
├── common-functions              # 共享工具函数（服务 CRUD、链接）
├── functions                     # 暴露给其他插件的公共函数
├── help-functions                # 帮助文本生成
├── install                       # 插件安装触发器（拉取镜像、创建目录）
├── update -> install             # 符号链接：update 执行与 install 相同操作
├── pre-start                     # 触发器：确保链接的 Temporal 服务正在运行
├── pre-delete                    # 触发器：删除应用前取消链接服务
├── post-app-clone-setup          # 触发器：处理应用克隆
├── post-app-rename-setup         # 触发器：处理应用重命名
├── pre-restore                   # 触发器：处理备份恢复
├── service-list                  # 触发器：列出服务（Dokku 服务管理）
├── subcommands/                  # 每个子命令一个文件
│   ├── create                    # temporal:create <service>      创建服务
│   ├── destroy                   # temporal:destroy <service>     销毁服务
│   ├── link                      # temporal:link <service> <app>  链接到应用
│   ├── unlink                    # temporal:unlink <service> <app>取消链接
│   ├── info                      # temporal:info <service>        显示信息
│   ├── start                     # temporal:start <service>       启动服务
│   ├── stop                      # temporal:stop <service>        停止服务
│   ├── restart                   # temporal:restart <service>     重启服务
│   ├── logs                      # temporal:logs <service>        查看日志
│   ├── expose                    # temporal:expose <service>      暴露端口
│   ├── unexpose                  # temporal:unexpose <service>    取消暴露
│   ├── exists                    # temporal:exists <service>      检查存在
│   ├── linked                    # temporal:linked <service> <app>检查链接
│   ├── links                     # temporal:links <service>       列出链接
│   ├── list                      # temporal:list                  列出全部
│   ├── set                       # temporal:set <service> <k> <v> 设置属性
│   ├── connect                   # temporal:connect <service>     打开 tctl
│   ├── namespace                 # temporal:namespace <svc> <ns>  管理命名空间
│   └── app-links                 # temporal:app-links <app>       应用链接
├── dynamicconfig/                # 默认 Temporal 动态配置模板
│   └── dynamic_config.yaml       # 默认动态配置
├── templates/                    # 配置模板
│   └── temporal-env.tmpl         # Temporal 容器环境变量模板
├── scripts/                      # 辅助脚本
│   └── setup-namespace.sh        # 服务启动后注册命名空间的脚本
├── tests/                        # 测试脚本
│   └── service_tests.bats        # BATS 测试套件
├── LICENSE.txt
└── README.md
```

## 文件约定

### 命名规则
- 触发器文件（hooks）：小写，连字符分隔，严格匹配 Dokku 触发器名（如 `pre-start`、`pre-delete`）
- 子命令文件：小写，连字符分隔，匹配命令后缀（如 `create` 对应 `temporal:create`）
- 所有可执行脚本：无文件扩展名
- 配置/数据文件：使用对应扩展名（`.toml`、`.yaml`、`.md`）

### 脚本头部

每个 bash 脚本必须以此开头：
```bash
#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"
set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x
```

### 运行时数据目录结构

创建服务时，在 `$DOKKU_LIB_ROOT/services/temporal/<service-name>/` 下生成：
```
<service-name>/
├── IMAGE                   # Docker 镜像名
├── IMAGE_VERSION           # Docker 镜像版本
├── PORT                    # gRPC 端口（默认 7233）
├── UI_PORT                 # Web UI 端口（默认 8233）
├── LINKS                   # 链接的应用列表
├── CONFIG_OPTIONS          # 额外容器选项
├── DATABASE_URL            # 完整 PostgreSQL 连接 URL（若设置）
├── POSTGRES_HOST           # Supabase 主机（如 db.xxxx.supabase.co）
├── POSTGRES_PORT           # PostgreSQL 端口（默认 5432）
├── POSTGRES_USER           # PostgreSQL 用户
├── POSTGRES_PWD            # PostgreSQL 密码
├── POSTGRES_DB             # 主数据库名（默认 temporal）
├── POSTGRES_DB_VISIBILITY  # 可见性数据库名（默认 temporal_visibility）
├── POSTGRES_TLS            # 是否启用 TLS（Supabase 默认 true）
├── ID                      # Docker 容器 ID
├── IP                      # 容器 IP 地址
├── dynamicconfig/          # 服务专属动态配置
│   └── dynamic_config.yaml
└── data/                   # 持久化数据卷挂载
```

## 核心配置变量（`config` 文件）

```bash
PLUGIN_COMMAND_PREFIX="temporal"     # 命令前缀
PLUGIN_SERVICE="Temporal"            # 服务显示名
PLUGIN_VARIABLE="TEMPORAL"           # 环境变量前缀
PLUGIN_DEFAULT_ALIAS="TEMPORAL"      # 默认别名
PLUGIN_SCHEME="temporal"             # URL scheme
PLUGIN_DATASTORE_PORTS=(7233)        # 数据存储端口
PLUGIN_DATASTORE_WAIT_PORT=7233      # 等待就绪端口
PLUGIN_IMAGE="temporalio/auto-setup" # 默认 Docker 镜像
PLUGIN_IMAGE_VERSION="1.25.2"        # 默认镜像版本
```
