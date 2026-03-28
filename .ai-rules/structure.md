---
title: Project Structure
description: "Defines the directory layout, file naming conventions, and organization rules."
inclusion: always
---

# dokku-temporal - Project Structure

## Directory Layout

```
dokku-temporal/
├── .ai-rules/                    # AI steering files
│   ├── product.md
│   ├── tech.md
│   └── structure.md
├── plugin.toml                   # Plugin metadata (name, version, description)
├── Dockerfile                    # Base image reference (temporalio/auto-setup:1.25.2)
├── config                        # Plugin configuration variables (exports)
├── commands                      # Command router and help output
├── common-functions              # Shared utility functions (service CRUD, linking)
├── functions                     # Public functions exposed to other plugins
├── help-functions                # Help text generation
├── install                       # Plugin installation trigger (pull images, create dirs)
├── update -> install             # Symlink: update runs the same as install
├── pre-start                     # Trigger: ensure linked Temporal services are running
├── pre-delete                    # Trigger: unlink services before app deletion
├── post-app-clone-setup          # Trigger: handle app cloning
├── post-app-rename-setup         # Trigger: handle app renaming
├── pre-restore                   # Trigger: handle backup restore
├── service-list                  # Trigger: list services for Dokku service management
├── subcommands/                  # One file per subcommand
│   ├── create                    # temporal:create <service>
│   ├── destroy                   # temporal:destroy <service>
│   ├── link                      # temporal:link <service> <app>
│   ├── unlink                    # temporal:unlink <service> <app>
│   ├── info                      # temporal:info <service>
│   ├── start                     # temporal:start <service>
│   ├── stop                      # temporal:stop <service>
│   ├── restart                   # temporal:restart <service>
│   ├── logs                      # temporal:logs <service>
│   ├── expose                    # temporal:expose <service> [ports]
│   ├── unexpose                  # temporal:unexpose <service>
│   ├── exists                    # temporal:exists <service>
│   ├── linked                    # temporal:linked <service> <app>
│   ├── links                     # temporal:links <service>
│   ├── list                      # temporal:list
│   ├── set                       # temporal:set <service> <key> <value>
│   ├── connect                   # temporal:connect <service> (open tctl shell)
│   ├── namespace                 # temporal:namespace <service> <namespace>
│   └── app-links                 # temporal:app-links <app>
├── dynamicconfig/                # Default Temporal dynamic config templates
│   └── dynamic_config.yaml       # Default dynamic configuration
├── templates/                    # Configuration templates
│   └── temporal-env.tmpl         # Environment variable template for Temporal container
├── scripts/                      # Helper scripts
│   └── setup-namespace.sh        # Script to register namespaces after server starts
├── tests/                        # Test scripts
│   └── service_tests.bats        # BATS test suite
├── LICENSE.txt
└── README.md
```

## File Conventions

### Naming Rules
- Trigger files (hooks): lowercase, hyphen-separated, matching Dokku trigger names exactly (e.g., `pre-start`, `pre-delete`)
- Subcommand files: lowercase, hyphen-separated, matching the command suffix (e.g., `create` for `temporal:create`)
- All executable scripts: no file extension
- Configuration/data files: use appropriate extensions (`.toml`, `.yaml`, `.md`)

### Script Headers
Every bash script must begin with:
```bash
#!/usr/bin/env bash
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/config"
set -eo pipefail
[[ $DOKKU_TRACE ]] && set -x
```

### Data Directory Structure (Runtime)
When a service is created, the following structure is created at `$DOKKU_LIB_ROOT/services/temporal/<service-name>/`:
```
<service-name>/
├── IMAGE                # Docker image name
├── IMAGE_VERSION        # Docker image version
├── PORT                 # gRPC port (default 7233)
├── UI_PORT              # Web UI port (default 8233)
├── LINKS                # File listing linked apps
├── CONFIG_OPTIONS       # Additional container options
├── DATABASE_URL         # Full PostgreSQL connection URL (if set)
├── POSTGRES_HOST        # Supabase host (e.g., db.xxxx.supabase.co)
├── POSTGRES_PORT        # PostgreSQL port (default 5432)
├── POSTGRES_USER        # PostgreSQL user
├── POSTGRES_PWD         # PostgreSQL password
├── POSTGRES_DB          # Main database name (default: temporal)
├── POSTGRES_DB_VISIBILITY # Visibility database name (default: temporal_visibility)
├── POSTGRES_TLS         # Enable TLS (default: true for Supabase)
├── ID                   # Docker container ID
├── IP                   # Container IP address
├── dynamicconfig/       # Service-specific dynamic config
│   └── dynamic_config.yaml
└── data/                # Persistent data volume mount
```

## Key Config Variables (from `config` file)

```bash
PLUGIN_COMMAND_PREFIX="temporal"
PLUGIN_SERVICE="Temporal"
PLUGIN_VARIABLE="TEMPORAL"
PLUGIN_DEFAULT_ALIAS="TEMPORAL"
PLUGIN_SCHEME="temporal"
PLUGIN_DATASTORE_PORTS=(7233)
PLUGIN_DATASTORE_WAIT_PORT=7233
PLUGIN_IMAGE="temporalio/auto-setup"
PLUGIN_IMAGE_VERSION="1.25.2"
```
