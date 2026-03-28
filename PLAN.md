# dokku-temporal 分阶段实施计划

## 概览

将 dokku-temporal 插件的实现拆分为 6 个阶段，每个阶段可独立验证。所有阶段严格遵循 Dokku 官方服务插件模式。

---

## Phase 1: 插件骨架

**目标**: 建立项目基础结构，完成 `dokku help temporal` 能正常输出帮助信息。

### 创建文件

- [ ] 1.1 `plugin.toml` -- 插件元数据
  ```toml
  [plugin]
  description = "dokku temporal service plugin"
  version = "0.1.0"
  [plugin.config]
  ```

- [ ] 1.2 `config` -- 核心配置变量导出
  - 导出 `PLUGIN_COMMAND_PREFIX="temporal"`
  - 导出 `PLUGIN_SERVICE="Temporal"`
  - 导出 `PLUGIN_VARIABLE="TEMPORAL"`
  - 导出 `PLUGIN_DEFAULT_ALIAS="TEMPORAL"`
  - 导出 `PLUGIN_SCHEME="temporal"`
  - 导出 `PLUGIN_DATASTORE_PORTS=(7233)`
  - 导出 `PLUGIN_DATASTORE_WAIT_PORT=7233`
  - 导出 `PLUGIN_IMAGE="temporalio/auto-setup"`
  - 导出 `PLUGIN_IMAGE_VERSION="1.25.2"`
  - 导出 `PLUGIN_BASE_PATH="$DOKKU_LIB_ROOT/services/temporal"`
  - 导出 `DOCKER_BIN` 检测逻辑

- [ ] 1.3 `commands` -- 命令路由入口
  - 解析 `$1` 子命令并路由到 `subcommands/` 目录
  - 处理 `temporal:help` 和无参数时输出帮助信息
  - 对未知命令输出错误提示

- [ ] 1.4 `help-functions` -- 帮助文本生成
  - `help_content()` 函数：输出所有命令的帮助文本
  - `help_list()` 函数：输出命令列表

- [ ] 1.5 `common-functions` -- 共享工具函数（初始版本）
  - `service_root()` -- 返回 `$PLUGIN_BASE_PATH/<service>`
  - `service_exists()` -- 检查服务目录是否存在
  - `service_container_name()` -- 返回 `dokku.temporal.<service>`
  - `is_container_running()` -- 检查容器是否运行中
  - `verify_service_name()` -- 校验服务名合法性
  - `require_service()` -- 断言服务存在，否则报错退出

- [ ] 1.6 `functions` -- 暴露给其他插件的公共函数（空框架）

- [ ] 1.7 `install` -- 插件安装触发器
  - 拉取 `temporalio/auto-setup:1.25.2` 镜像
  - 拉取 `temporalio/ui:2.32.0` 镜像
  - 拉取 `dokku/ambassador:0.8.2` 镜像
  - 拉取 `dokku/wait:0.9.3` 镜像
  - 创建 `$PLUGIN_BASE_PATH` 目录

- [ ] 1.8 `update -> install` -- 符号链接

- [ ] 1.9 `subcommands/` 目录 -- 创建空目录

- [ ] 1.10 `dynamicconfig/dynamic_config.yaml` -- 默认动态配置
  ```yaml
  # Temporal dynamic configuration
  # See: https://docs.temporal.io/references/dynamic-configuration
  ```

- [ ] 1.11 所有文件设置可执行权限 `chmod +x`

### 验证步骤

```bash
# 手动验证（在 Dokku 服务器上）
# 1. 安装插件
dokku plugin:install /path/to/dokku-temporal

# 2. 验证帮助输出
dokku temporal:help
# 预期：输出所有命令列表

# 3. 验证 install 触发器
docker images | grep temporalio
# 预期：能看到 temporalio/auto-setup:1.25.2

# 4. 验证目录创建
ls -la /var/lib/dokku/services/temporal/
# 预期：目录存在，权限正确
```

---

## Phase 2: 核心服务管理

**目标**: 实现 create/destroy/start/stop/restart/info/exists/list 命令，能成功启动连接远程 Supabase PostgreSQL 的 Temporal 容器。

**依赖**: Phase 1

### 创建/修改文件

- [ ] 2.1 `subcommands/create` -- 创建服务
  - 校验服务名合法性（字母数字和连字符）
  - 创建服务目录 `$PLUGIN_BASE_PATH/<service>/`
  - 写入默认文件：IMAGE, IMAGE_VERSION, PORT(7233), UI_PORT(8233), LINKS(空)
  - 复制默认 `dynamicconfig/` 到服务目录
  - 设置目录权限 `700`，文件权限 `600`（凭据文件）
  - 输出后续配置提示（提示设置 POSTGRES_* 参数）

- [ ] 2.2 `subcommands/destroy` -- 销毁服务
  - 确认提示（支持 `--force` 跳过）
  - 停止并删除容器
  - 清理链接（取消所有已链接应用的环境变量）
  - 删除服务目录
  - 如果有 UI 容器 `dokku.temporal.<service>.ui` 也一并删除

- [ ] 2.3 `subcommands/set` -- 设置服务属性
  - 支持 key-value 对写入服务目录文件
  - 允许的 key：POSTGRES_HOST, POSTGRES_PORT, POSTGRES_USER, POSTGRES_PWD, POSTGRES_DB, POSTGRES_DB_VISIBILITY, POSTGRES_TLS, DATABASE_URL, IMAGE, IMAGE_VERSION, CONFIG_OPTIONS
  - 凭据类 key 设置 `chmod 600`
  - 设置完成后输出当前配置摘要

- [ ] 2.4 `subcommands/start` -- 启动服务
  - 检查服务是否存在
  - 检查容器是否已在运行
  - 构建 PostgreSQL 连接参数（优先 DATABASE_URL 解析，否则用分字段拼接）
  - 构建 `docker run` 命令：
    - `--name dokku.temporal.<service>`
    - `--restart on-failure:5`
    - `-e DB=postgres12`
    - `-e DB_PORT=<port>`
    - `-e POSTGRES_USER=<user>`
    - `-e POSTGRES_PWD=<pwd>`
    - `-e POSTGRES_SEEDS=<host>`
    - `-e POSTGRES_TLS=<true/false>`
    - `-e POSTGRES_TLS_DISABLE_HOST_VERIFICATION=true`
    - `-e DBNAME=<db>`
    - `-e VISIBILITY_DBNAME=<visibility_db>`
    - `-e DYNAMIC_CONFIG_FILE_PATH=/etc/temporal/config/dynamicconfig/dynamic_config.yaml`
    - `-e DEFAULT_NAMESPACE=default`
    - `-v <service-dir>/dynamicconfig:/etc/temporal/config/dynamicconfig:ro`
    - `--network dokku` (如果存在) 或创建 bridge 网络
  - 使用 `dokku/wait` 容器检查 7233 端口就绪
  - 记录容器 ID 到 `ID` 文件，IP 到 `IP` 文件

- [ ] 2.5 `subcommands/stop` -- 停止服务
  - 检查服务是否存在
  - 停止容器 `$DOCKER_BIN stop`
  - 删除容器 `$DOCKER_BIN rm`
  - 清空 ID 和 IP 文件

- [ ] 2.6 `subcommands/restart` -- 重启服务
  - 调用 stop 再调用 start

- [ ] 2.7 `subcommands/info` -- 显示服务信息
  - 输出：服务状态（running/stopped）、容器名、镜像版本、gRPC 端口、PostgreSQL 主机（密码脱敏 `****`）、链接的应用列表、数据目录路径
  - 支持 `--show-password` 显示明文密码

- [ ] 2.8 `subcommands/exists` -- 检查服务是否存在
  - 退出码 0 表示存在，1 表示不存在

- [ ] 2.9 `subcommands/list` -- 列出所有服务
  - 遍历 `$PLUGIN_BASE_PATH/` 下的目录
  - 输出格式：服务名 | 状态 | 镜像版本

- [ ] 2.10 `common-functions` 更新 -- 新增工具函数
  - `get_postgres_env()` -- 读取服务的 PostgreSQL 配置，构建环境变量数组
  - `parse_database_url()` -- 解析 DATABASE_URL 为各分字段
  - `get_service_url()` -- 生成 `temporal://<container-name>:7233` URL
  - `docker_ports_options()` -- 生成端口映射参数

- [ ] 2.11 `service-list` -- Dokku 服务列表触发器
  - 响应 `dokku service:list` 的 `service-list` 触发器

### 验证步骤

```bash
# 1. 创建服务
dokku temporal:create main
# 预期：创建成功，输出配置提示

# 2. 配置 Supabase 连接
dokku temporal:set main POSTGRES_HOST db.xxxx.supabase.co
dokku temporal:set main POSTGRES_PORT 5432
dokku temporal:set main POSTGRES_USER postgres
dokku temporal:set main POSTGRES_PWD your-password
dokku temporal:set main POSTGRES_TLS true

# 3. 启动服务
dokku temporal:start main
# 预期：容器启动，auto-setup 自动建表

# 4. 检查服务信息
dokku temporal:info main
# 预期：显示 running 状态，PostgreSQL 密码脱敏

# 5. 检查容器状态
docker ps | grep dokku.temporal.main
# 预期：容器运行中

# 6. 检查 Temporal 是否就绪
docker exec dokku.temporal.main tctl cluster health
# 预期：SERVING

# 7. 停止服务
dokku temporal:stop main
docker ps -a | grep dokku.temporal.main
# 预期：容器已停止并删除

# 8. 列出服务
dokku temporal:list
# 预期：显示 main 服务

# 9. 销毁服务
dokku temporal:destroy main --force
ls /var/lib/dokku/services/temporal/main
# 预期：目录不存在

# 10. 检查服务存在性
dokku temporal:exists main
echo $?
# 预期：退出码 1
```

---

## Phase 3: 应用链接

**目标**: 实现 link/unlink 及相关查询命令，应用能通过 `TEMPORAL_ADDRESS` 环境变量连接 Temporal。

**依赖**: Phase 2

### 创建/修改文件

- [ ] 3.1 `subcommands/link` -- 链接到应用
  - 校验服务和应用都存在
  - 检查是否已链接（避免重复）
  - 确保 Temporal 容器正在运行（不在运行则自动启动）
  - 确保应用和 Temporal 容器在同一 Docker 网络
  - 注入环境变量到应用：
    - `TEMPORAL_URL=temporal://dokku.temporal.<service>:7233`
    - `TEMPORAL_ADDRESS=dokku.temporal.<service>:7233`
    - `TEMPORAL_NAMESPACE=default`
  - 支持 `--alias` 参数自定义环境变量前缀
  - 支持 `--namespace` 参数指定非默认命名空间
  - 将应用名追加到服务的 `LINKS` 文件
  - 重启应用使环境变量生效

- [ ] 3.2 `subcommands/unlink` -- 取消链接
  - 校验服务和应用都存在
  - 检查是否已链接
  - 从应用中移除 TEMPORAL_* 环境变量
  - 从服务的 `LINKS` 文件中移除应用名
  - 重启应用

- [ ] 3.3 `subcommands/linked` -- 检查链接状态
  - 退出码 0 表示已链接，1 表示未链接

- [ ] 3.4 `subcommands/links` -- 列出链接的应用
  - 读取服务的 `LINKS` 文件并输出

- [ ] 3.5 `subcommands/app-links` -- 列出应用链接的 Temporal 服务
  - 遍历所有服务，检查 LINKS 文件中是否包含目标应用

- [ ] 3.6 `pre-start` -- 触发器：应用启动前确保 Temporal 运行
  - 当链接的应用启动时，检查关联的 Temporal 服务是否运行
  - 如未运行则自动启动

- [ ] 3.7 `pre-delete` -- 触发器：应用删除前自动 unlink
  - 当应用被删除时，自动从所有关联的 Temporal 服务中取消链接

- [ ] 3.8 `post-app-clone-setup` -- 触发器：处理应用克隆
  - 克隆应用时，复制 Temporal 链接关系到新应用

- [ ] 3.9 `post-app-rename-setup` -- 触发器：处理应用重命名
  - 重命名应用时，更新 Temporal 服务的 LINKS 文件

- [ ] 3.10 `pre-restore` -- 触发器：处理备份恢复
  - 恢复应用时，重建 Temporal 链接关系

### 验证步骤

```bash
# 准备：创建并启动 Temporal 服务
dokku temporal:create main
dokku temporal:set main POSTGRES_HOST db.xxxx.supabase.co
# ... 其他配置 ...
dokku temporal:start main

# 准备：创建测试应用
dokku apps:create test-worker

# 1. 链接
dokku temporal:link main test-worker
# 预期：输出注入的环境变量

# 2. 检查环境变量
dokku config:show test-worker | grep TEMPORAL
# 预期：
#   TEMPORAL_URL=temporal://dokku.temporal.main:7233
#   TEMPORAL_ADDRESS=dokku.temporal.main:7233
#   TEMPORAL_NAMESPACE=default

# 3. 检查链接状态
dokku temporal:linked main test-worker
echo $?
# 预期：退出码 0

# 4. 列出链接
dokku temporal:links main
# 预期：test-worker

# 5. 取消链接
dokku temporal:unlink main test-worker
dokku config:show test-worker | grep TEMPORAL
# 预期：无 TEMPORAL_* 变量

# 6. 测试 pre-start 触发器
dokku temporal:link main test-worker
dokku temporal:stop main
dokku ps:restart test-worker
docker ps | grep dokku.temporal.main
# 预期：Temporal 自动启动

# 7. 测试 pre-delete 触发器
dokku apps:destroy test-worker --force
dokku temporal:links main
# 预期：链接列表为空
```

---

## Phase 4: 高级功能

**目标**: 实现端口暴露、日志查看、命名空间管理和 Web UI 控制。

**依赖**: Phase 3

### 创建/修改文件

- [ ] 4.1 `subcommands/expose` -- 暴露端口
  - 默认绑定 `127.0.0.1`（安全）
  - 支持 `--public` 标志绑定 `0.0.0.0`（带警告确认）
  - 使用 `dokku/ambassador` 容器代理
  - 默认暴露端口：7233（gRPC）
  - 可选暴露：8233（UI，仅在 UI 启用后）
  - 将暴露配置写入服务目录 `PORT_MAP` 文件

- [ ] 4.2 `subcommands/unexpose` -- 取消端口暴露
  - 停止并删除 ambassador 容器
  - 清除 `PORT_MAP` 文件

- [ ] 4.3 `subcommands/logs` -- 查看日志
  - `$DOCKER_BIN logs` 转发
  - 支持 `-t`/`--tail` 参数指定行数
  - 支持 `--follow` 持续输出

- [ ] 4.4 `subcommands/namespace` -- 命名空间管理
  - `temporal:namespace <service> create <ns>` -- 创建命名空间
  - `temporal:namespace <service> list` -- 列出命名空间
  - 通过 `docker exec` 在 Temporal 容器内执行 `tctl` 命令
  - 创建完成后输出提示：可在 link 时使用 `--namespace <ns>`

- [ ] 4.5 `subcommands/connect` -- 打开 tctl 交互 shell
  - `docker exec -it dokku.temporal.<service> tctl`

- [ ] 4.6 `scripts/setup-namespace.sh` -- 命名空间初始化脚本
  - 服务启动后自动注册 `default` 命名空间（如不存在）
  - 被 `subcommands/start` 在容器就绪后调用

- [ ] 4.7 新增 UI 管理命令（扩展 `subcommands/set` 或独立文件）
  - `temporal:set <service> UI_ENABLED true` -- 启用 UI
  - 启用后 start 命令额外启动 UI 容器 `dokku.temporal.<service>.ui`
  - UI 容器使用 `temporalio/ui:2.32.0`
  - UI 容器环境变量：`TEMPORAL_ADDRESS=dokku.temporal.<service>:7233`
  - UI 容器仅绑定 `127.0.0.1:8233`

- [ ] 4.8 更新 `subcommands/start` -- 支持 UI 容器
  - 检查 `UI_ENABLED` 文件，如为 `true` 则同时启动 UI 容器

- [ ] 4.9 更新 `subcommands/stop` -- 支持 UI 容器
  - 同时停止 UI 容器

- [ ] 4.10 更新 `subcommands/info` -- 显示 UI 和暴露信息
  - 增加 UI 状态显示
  - 增加暴露端口信息

### 验证步骤

```bash
# 1. 端口暴露
dokku temporal:expose main 7233
ss -tlnp | grep 7233
# 预期：127.0.0.1:7233 监听

# 2. 取消暴露
dokku temporal:unexpose main
ss -tlnp | grep 7233
# 预期：无监听

# 3. 公网暴露警告
dokku temporal:expose main --public 7233
# 预期：输出安全警告并要求确认

# 4. 查看日志
dokku temporal:logs main --tail 20
# 预期：显示最近 20 行日志

# 5. 创建命名空间
dokku temporal:namespace main create my-namespace
# 预期：命名空间创建成功

# 6. 列出命名空间
dokku temporal:namespace main list
# 预期：显示 default 和 my-namespace

# 7. 启用 UI
dokku temporal:set main UI_ENABLED true
dokku temporal:restart main
docker ps | grep dokku.temporal.main.ui
# 预期：UI 容器运行中

# 8. UI 访问（通过 SSH 隧道）
# 本地执行：ssh -L 8233:localhost:8233 <dokku-server>
# 浏览器打开：http://localhost:8233
# 预期：Temporal UI 界面

# 9. tctl 交互
dokku temporal:connect main
# 预期：进入 tctl shell，可执行 tctl namespace list 等命令
```

---

## Phase 5: 安全加固与测试

**目标**: 实施所有安全策略，编写自动化测试。

**依赖**: Phase 4

### 创建/修改文件

- [ ] 5.1 安全加固 -- 审查并加固所有已有脚本
  - 确保所有凭据文件权限为 `600`
  - 确保服务目录权限为 `700`
  - 确保 `info` 命令默认脱敏密码
  - 确保 expose 命令默认绑定 `127.0.0.1`
  - 确保 `--public` 标志触发安全警告

- [ ] 5.2 输入校验加固
  - 服务名校验：仅允许 `[a-z0-9-]`，长度 1-32
  - 命名空间名校验：仅允许 `[a-zA-Z0-9_-]`
  - 端口号校验：1024-65535 范围
  - DATABASE_URL 格式校验

- [ ] 5.3 错误处理完善
  - 所有命令添加友好的错误提示
  - PostgreSQL 连接失败的诊断提示
  - 容器启动失败时输出最近日志
  - Supabase TLS 连接失败的特定提示

- [ ] 5.4 `tests/service_tests.bats` -- BATS 测试套件
  - 测试用例：
    - `create` 创建服务目录和默认文件
    - `create` 拒绝非法服务名
    - `create` 拒绝重复创建
    - `set` 写入配置文件
    - `set` 凭据文件权限为 600
    - `exists` 返回正确退出码
    - `list` 输出格式正确
    - `destroy --force` 清理所有资源
    - `info` 默认脱敏密码
    - `info --show-password` 显示明文
    - `link` 注入正确环境变量
    - `unlink` 移除环境变量
    - `linked` 返回正确退出码
    - `expose` 默认绑定 127.0.0.1
    - `namespace create` 创建命名空间

- [ ] 5.5 `tests/helpers.bash` -- 测试辅助函数
  - `setup()` -- 创建临时测试环境
  - `teardown()` -- 清理测试资源
  - mock Docker 命令（避免测试依赖真实 Docker）

- [ ] 5.6 `.github/workflows/test.yml`（可选） -- CI 测试配置

### 验证步骤

```bash
# 1. 运行 BATS 测试
bats tests/service_tests.bats
# 预期：所有测试通过

# 2. 安全检查
ls -la /var/lib/dokku/services/temporal/main/POSTGRES_PWD
# 预期：-rw------- dokku dokku

ls -la /var/lib/dokku/services/temporal/main/
# 预期：drwx------ dokku dokku

# 3. 密码脱敏检查
dokku temporal:info main 2>&1 | grep "****"
# 预期：密码显示为 ****

# 4. 非法输入测试
dokku temporal:create "invalid name!"
# 预期：错误提示

dokku temporal:create main
# 预期：服务已存在的错误提示
```

---

## Phase 6: 自动启动与生产就绪

**目标**: Temporal 服务随 Dokku 自动启动，文档完善，达到生产可用状态。

**依赖**: Phase 5

### 创建/修改文件

- [ ] 6.1 自动启动方案实现
  - **方案**: 利用 Docker `--restart on-failure:5` 策略（已在 Phase 2 的 start 命令中设置）
  - 补充：在 `install` 触发器中注册 systemd 单元或利用 Dokku 的 `post-dokku-startup` 触发器
  - 创建 `post-dokku-startup` 触发器文件：
    - 遍历所有 Temporal 服务
    - 检查每个服务是否有 `AUTOSTART` 标记（默认 true）
    - 对标记为 autostart 的服务执行 start

- [ ] 6.2 `post-dokku-startup` -- 触发器：Dokku 启动后自动启动服务
  - 遍历 `$PLUGIN_BASE_PATH/` 下所有服务目录
  - 读取每个服务的 `AUTOSTART` 文件（不存在则默认 true）
  - 对 autostart=true 的服务调用 start 逻辑
  - 处理并发启动（单个失败不影响其他）

- [ ] 6.3 更新 `subcommands/set` -- 支持 `AUTOSTART` 配置
  - `dokku temporal:set <service> AUTOSTART false` 可禁用自动启动

- [ ] 6.4 健康检查机制
  - 在 start 命令中增加启动后健康检查循环
  - 检查 gRPC 端口 7233 可达性
  - 超时 60 秒后报错（输出容器日志辅助排查）

- [ ] 6.5 `README.md` -- 完整使用文档
  - 安装说明
  - 快速开始（Supabase 配置 + 服务创建 + 链接应用）
  - 命令参考
  - 安全注意事项
  - 故障排查指南
  - Supabase PostgreSQL 准备步骤

- [ ] 6.6 `LICENSE.txt` -- 开源许可证

- [ ] 6.7 生产加固
  - 审查所有 `docker run` 参数
  - 确保容器资源限制（可选：`--memory`, `--cpus`）
  - 确保日志不会无限增长（`--log-opt max-size=10m --log-opt max-file=3`）
  - 验证 `--restart on-failure:5` 在各种故障场景下的行为

- [ ] 6.8 版本升级支持
  - 在 `subcommands/set` 中支持 `IMAGE_VERSION` 修改
  - restart 后使用新版本镜像
  - 文档中说明 auto-setup 到 server 镜像的切换方式

### 验证步骤

```bash
# 1. 自动启动测试
dokku temporal:create main
# ... 配置并启动 ...
sudo systemctl restart dokku
# 等待 Dokku 启动完成
docker ps | grep dokku.temporal.main
# 预期：Temporal 容器自动启动

# 2. 禁用自动启动
dokku temporal:set main AUTOSTART false
sudo systemctl restart dokku
docker ps | grep dokku.temporal.main
# 预期：Temporal 容器未启动

# 3. 服务器重启测试（Docker restart policy）
sudo reboot
# 重启后
docker ps | grep dokku.temporal.main
# 预期：由 Docker restart policy 自动恢复

# 4. 健康检查测试
dokku temporal:start main
# 预期：输出健康检查进度，最终显示 "Temporal is ready"

# 5. 完整端到端测试
dokku temporal:create production
dokku temporal:set production POSTGRES_HOST db.xxxx.supabase.co
dokku temporal:set production POSTGRES_PORT 5432
dokku temporal:set production POSTGRES_USER temporal_user
dokku temporal:set production POSTGRES_PWD strong-password
dokku temporal:set production POSTGRES_TLS true
dokku temporal:start production
dokku temporal:namespace production create my-app-ns
dokku temporal:link production my-worker --namespace my-app-ns
dokku config:show my-worker | grep TEMPORAL
# 预期：
#   TEMPORAL_URL=temporal://dokku.temporal.production:7233
#   TEMPORAL_ADDRESS=dokku.temporal.production:7233
#   TEMPORAL_NAMESPACE=my-app-ns
dokku temporal:set production UI_ENABLED true
dokku temporal:restart production
dokku temporal:info production
# 预期：完整服务信息，包含 UI 状态
dokku temporal:destroy production --force
```

---

## 阶段依赖关系

```
Phase 1 (骨架)
    |
    v
Phase 2 (核心服务管理)
    |
    v
Phase 3 (应用链接)
    |
    v
Phase 4 (高级功能)
    |
    v
Phase 5 (安全加固与测试)
    |
    v
Phase 6 (自动启动与生产就绪)
```

每个阶段完成后都可以在 Dokku 服务器上独立验证，无需后续阶段的功能。

## 工作量估算

| 阶段 | 预计文件数 | 预计工时 |
|------|-----------|---------|
| Phase 1 | 8-10 | 2-3h |
| Phase 2 | 10-12 | 4-6h |
| Phase 3 | 8-10 | 3-4h |
| Phase 4 | 8-10 | 3-4h |
| Phase 5 | 3-5 | 2-3h |
| Phase 6 | 5-7 | 2-3h |
| **总计** | **~50** | **~16-23h** |

## 关键设计决策记录

1. **不依赖 dokku-postgres**: 所有 PostgreSQL 连接通过手动配置的 Supabase 远程参数，避免本地依赖。
2. **auto-setup 镜像优先**: 初始创建使用 `temporalio/auto-setup` 自动建表，后续可切换 `temporalio/server`。
3. **UI 默认关闭**: Web UI 需手动启用，启用后仅绑定 localhost，通过 SSH 隧道访问。
4. **Docker 网络策略**: 使用 Dokku 默认的 `bridge` 网络或 `dokku` 网络，确保链接的应用能通过容器名访问 Temporal。
5. **自动启动双保险**: Docker `--restart on-failure:5` 处理容器级重启 + `post-dokku-startup` 触发器处理 Dokku 级重启。
