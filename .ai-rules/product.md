---
title: Product Vision
description: "Defines the project's core purpose, target users, and main features."
inclusion: always
---

# dokku-temporal - Product Vision

## Purpose

A Dokku plugin that provisions and manages a shared Temporal Server instance, allowing any Dokku-deployed application to connect to it as a workflow orchestration engine. This follows the same service plugin pattern used by official Dokku plugins (dokku-postgres, dokku-redis, etc.).

## Problem Statement

BlackSail project applications require Temporal for durable workflow execution (e.g., background jobs, long-running processes, scheduled tasks). Without this plugin, each deployment would need manual Temporal setup, Docker networking configuration, and environment variable management. This plugin automates all of that into standard Dokku commands.

## Target Users

- DevOps engineers deploying BlackSail applications to Dokku servers
- Developers who need Temporal workflow capabilities in their Dokku apps

## Core Features

1. **Service Lifecycle Management** -- Create, destroy, start, stop, and restart Temporal server instances via `dokku temporal:create`, `dokku temporal:destroy`, etc.
2. **App Linking** -- Link/unlink Temporal to Dokku apps via `dokku temporal:link <service> <app>`, automatically injecting `TEMPORAL_ADDRESS` and `TEMPORAL_NAMESPACE` environment variables.
3. **Persistent Storage** -- Temporal state persists across container restarts using a linked PostgreSQL database (via the existing dokku-postgres plugin).
4. **Web UI Access** -- Expose the Temporal Web UI for workflow monitoring and debugging.
5. **Multi-Namespace Support** -- Support creating and managing multiple Temporal namespaces for different apps or environments.
6. **Configuration Management** -- Allow customization of Temporal dynamic config, gRPC ports, and other settings per service instance.

## Non-Goals

- This plugin does NOT replace a production-grade Temporal Cloud deployment. It is intended for self-hosted Dokku environments.
- This plugin does NOT manage Temporal workers. Workers run inside the linked applications.

## Key Environment Variables Injected into Linked Apps

| Variable | Example Value | Description |
|---|---|---|
| `TEMPORAL_URL` | `temporal://dokku-temporal-main:7233` | Full service URL (Dokku convention) |
| `TEMPORAL_ADDRESS` | `dokku-temporal-main:7233` | gRPC endpoint for Temporal SDK clients |
| `TEMPORAL_NAMESPACE` | `default` | Temporal namespace for the linked app |

## Command Reference (Target)

```
temporal:create <service>          Create a Temporal service
temporal:destroy <service>         Destroy a Temporal service
temporal:link <service> <app>      Link Temporal to an app
temporal:unlink <service> <app>    Unlink Temporal from an app
temporal:info <service>            Display service info
temporal:start <service>           Start the service
temporal:stop <service>            Stop the service
temporal:restart <service>         Restart the service
temporal:logs <service>            Display service logs
temporal:expose <service> [ports]  Expose ports on the host
temporal:unexpose <service>        Unexpose ports
temporal:exists <service>          Check if service exists
temporal:linked <service> <app>    Check if service is linked to app
temporal:links <service>           List apps linked to service
temporal:list                      List all Temporal services
temporal:set <service> <key> <val> Set a service property
temporal:namespace <service> <ns>  Create/register a namespace
```
