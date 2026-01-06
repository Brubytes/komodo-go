# Komodo API Reference

This document provides a quick reference for the Komodo API used in this Flutter app.

## Overview

Komodo Core exposes an RPC-like HTTP API. All requests are POST requests with JSON bodies.

**Base URL**: `https://your-komodo-instance.com`

**Authentication**: API Key/Secret headers
```
X-Api-Key: <your-api-key>
X-Api-Secret: <your-api-secret>
```

## Request Format

All requests follow this pattern:
```json
POST /<module>
{
  "type": "<OperationType>",
  "params": { ... }
}
```

Modules: `/auth`, `/read`, `/write`, `/execute`, `/terminal`

---

## Auth Module (`/auth`)

### GetLoginOptions
Get available login methods.
```json
{ "type": "GetLoginOptions", "params": {} }
```

### GetUser
Get authenticated user info.
```json
{ "type": "GetUser", "params": {} }
```

---

## Read Module (`/read`)

### Servers

#### ListServers
```json
{ "type": "ListServers", "params": { "query": "" } }
```
Response: `{ "servers": [...] }`

#### GetServer
```json
{ "type": "GetServer", "params": { "server": "<id-or-name>" } }
```

#### GetServerState
```json
{ "type": "GetServerState", "params": { "server": "<id-or-name>" } }
```

#### GetSystemStats
Get CPU, memory, disk stats for a server.
```json
{ "type": "GetSystemStats", "params": { "server": "<id-or-name>" } }
```

#### GetSystemInformation
```json
{ "type": "GetSystemInformation", "params": { "server": "<id-or-name>" } }
```

### Deployments

#### ListDeployments
```json
{ "type": "ListDeployments", "params": { "query": "" } }
```
Response: `{ "deployments": [...] }`

#### GetDeployment
```json
{ "type": "GetDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### GetDeploymentActionState
```json
{ "type": "GetDeploymentActionState", "params": { "deployment": "<id-or-name>" } }
```

#### GetDeploymentContainer
```json
{ "type": "GetDeploymentContainer", "params": { "deployment": "<id-or-name>" } }
```

#### GetDeploymentLog
```json
{ "type": "GetDeploymentLog", "params": { "deployment": "<id-or-name>", "tail": 100 } }
```

#### GetDeploymentStats
Docker container stats.
```json
{ "type": "GetDeploymentStats", "params": { "deployment": "<id-or-name>" } }
```

### Builds

#### ListBuilds
List builds matching an optional structured query.
```json
{
  "type": "ListBuilds",
  "params": {
    "query": {
      "builder_ids": [],
      "repos": [],
      "built_since": 0
    }
  }
}
```
Response: `ListBuildsResponse` (array of `BuildListItem`)

#### ListFullBuilds
Like `ListBuilds`, but returns full `Build` resources.
```json
{ "type": "ListFullBuilds", "params": { "query": { } } }
```
Response: `ListFullBuildsResponse` (array of `Build`)

#### GetBuild
```json
{ "type": "GetBuild", "params": { "build": "<id-or-name>" } }
```
Response: `GetBuildResponse` (a `Build`)

#### GetBuildActionState
```json
{ "type": "GetBuildActionState", "params": { "build": "<id-or-name>" } }
```
Response: `GetBuildActionStateResponse` (a `BuildActionState`)

#### GetBuildsSummary
```json
{ "type": "GetBuildsSummary", "params": { } }
```
Response: `GetBuildsSummaryResponse`

#### GetBuildMonthlyStats
Paginated timeseries stats (1 page = 30 days). Use `page: 0` for most recent.
```json
{ "type": "GetBuildMonthlyStats", "params": { "page": 0 } }
```
Response: `GetBuildMonthlyStatsResponse`

#### ListBuildVersions
Returns versions available for deployment (newest first). Optional semver filtering.
```json
{
  "type": "ListBuildVersions",
  "params": {
    "build": "<id-or-name>",
    "major": null,
    "minor": null,
    "patch": null,
    "limit": null
  }
}
```
Response: `ListBuildVersionsResponse` (array of `BuildVersionResponseItem`)

#### ListCommonBuildExtraArgs
Returns a list of values used as build extra args across other builds (for suggestions).
```json
{ "type": "ListCommonBuildExtraArgs", "params": { "query": { } } }
```
Response: `ListCommonBuildExtraArgsResponse` (array of strings)

#### GetBuildWebhookEnabled
Whether the build’s linked repo has a webhook configured for the build.
```json
{ "type": "GetBuildWebhookEnabled", "params": { "build": "<id-or-name>" } }
```
Response: `GetBuildWebhookEnabledResponse`

### Repos

#### ListRepos
List repos matching an optional structured query.
```json
{
  "type": "ListRepos",
  "params": {
    "query": {
      "repos": []
    }
  }
}
```
Response: `ListReposResponse` (array of `RepoListItem`)

#### ListFullRepos
Like `ListRepos`, but returns full `Repo` resources.
```json
{ "type": "ListFullRepos", "params": { "query": { } } }
```
Response: `ListFullReposResponse` (array of `Repo`)

#### GetRepo
```json
{ "type": "GetRepo", "params": { "repo": "<id-or-name>" } }
```
Response: `GetRepoResponse` (a `Repo`)

#### GetRepoActionState
```json
{ "type": "GetRepoActionState", "params": { "repo": "<id-or-name>" } }
```
Response: `GetRepoActionStateResponse` (a `RepoActionState`)

#### GetReposSummary
```json
{ "type": "GetReposSummary", "params": { } }
```
Response: `GetReposSummaryResponse`

#### GetRepoWebhooksEnabled
Query which repo webhooks are enabled (clone/pull/build).
```json
{ "type": "GetRepoWebhooksEnabled", "params": { "repo": "<id-or-name>" } }
```
Response: `GetRepoWebhooksEnabledResponse`

### Stacks

#### ListStacks
```json
{ "type": "ListStacks", "params": { "query": { } } }
```
Response: `ListStacksResponse` (array)
```json
[
  {
    "_id": { "$oid": "..." },
    "name": "my-stack",
    "description": "",
    "resource_type": "Stack",
    "tags": [],
    "info": {
      "server_id": "server-id",
      "state": "Running",
      "status": "Ok",
      "project_name": "my-stack"
    },
    "updated_at": "..."
  }
]
```

#### GetStack
```json
{ "type": "GetStack", "params": { "stack": "<id-or-name>" } }
```
Response: `GetStackResponse` (stack resource)
```json
{
  "_id": { "$oid": "..." },
  "name": "my-stack",
  "description": "",
  "tags": [],
  "info": {
    "server_id": "server-id",
    "state": "Running",
    "status": "Ok",
    "project_name": "my-stack"
  },
  "config": { "...": "StackConfig" },
  "updated_at": "..."
}
```

#### ListStackServices
```json
{ "type": "ListStackServices", "params": { "stack": "<id-or-name>" } }
```
Response: `ListStackServicesResponse` (array)
```json
[
  {
    "service": "api",
    "image": "ghcr.io/acme/api:1.2.3",
    "container": null,
    "update_available": false
  }
]
```

#### GetStackActionState
Returns action-in-progress flags (useful to disable UI actions while the stack is busy).
```json
{ "type": "GetStackActionState", "params": { "stack": "<id-or-name>" } }
```
Response: `GetStackActionStateResponse`
```json
{
  "pulling": false,
  "deploying": false,
  "starting": false,
  "restarting": false,
  "pausing": false,
  "unpausing": false,
  "stopping": false,
  "destroying": false
}
```

#### GetStackLog
Fetch stack logs.
```json
{ "type": "GetStackLog", "params": { "stack": "<id-or-name>", "services": [], "tail": 50, "timestamps": false } }
```
Response: `GetStackLogResponse` (a `Log`)
```json
{
  "stage": "compose logs",
  "command": "docker compose logs ...",
  "stdout": "...",
  "stderr": "...",
  "success": true,
  "start_ts": 0,
  "end_ts": 0
}
```

#### SearchStackLog
Search the stack log’s tail using `grep` on the underlying server.
```json
{
  "type": "SearchStackLog",
  "params": {
    "stack": "<id-or-name>",
    "services": [],
    "terms": ["error", "timeout"],
    "combinator": "And",
    "invert": false,
    "timestamps": true
  }
}
```
Response: `SearchStackLogResponse` (a `Log`)

#### GetStackWebhooksEnabled
Query which stack webhooks are enabled.
```json
{ "type": "GetStackWebhooksEnabled", "params": { "stack": "<id-or-name>" } }
```
Response: `GetStackWebhooksEnabledResponse`
```json
{
  "managed": true,
  "refresh_enabled": true,
  "deploy_enabled": true
}
```

#### ListFullStacks
Like `ListStacks`, but returns full stack resources.
```json
{ "type": "ListFullStacks", "params": { "query": { } } }
```
Response: `ListFullStacksResponse` (array of `Stack`)

#### GetStacksSummary
Returns a summary (including `stacks`) plus a list of `errors`.
```json
{ "type": "GetStacksSummary", "params": { "query": { } } }
```
Response: `GetStacksSummaryResponse`
```json
{ "stacks": [/* same shape as ListStacksResponse items */], "errors": [] }
```

### Other Resources

#### GetVersion
```json
{ "type": "GetVersion", "params": {} }
```

#### GetCoreInfo
```json
{ "type": "GetCoreInfo", "params": {} }
```

---

## Execute Module (`/execute`)

### Deployment Actions

#### Deploy
```json
{ "type": "Deploy", "params": { "deployment": "<id-or-name>" } }
```

#### StartDeployment
```json
{ "type": "StartDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### StopDeployment
```json
{ "type": "StopDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### RestartDeployment
```json
{ "type": "RestartDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### PauseDeployment
```json
{ "type": "PauseDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### UnpauseDeployment
```json
{ "type": "UnpauseDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### DestroyDeployment
```json
{ "type": "DestroyDeployment", "params": { "deployment": "<id-or-name>" } }
```

#### PullDeployment
```json
{ "type": "PullDeployment", "params": { "deployment": "<id-or-name>" } }
```

### Build Actions

#### RunBuild
Runs a build (clone repo on builder, docker build, optional push, optional redeploy).
```json
{ "type": "RunBuild", "params": { "build": "<id-or-name>" } }
```
Response: `Update`

#### BatchRunBuild
Runs multiple builds matching `pattern` (id/name/wildcard/regex; supports multiline + comma lists).
```json
{ "type": "BatchRunBuild", "params": { "pattern": "foo-*\nextra-build-1, extra-build-2" } }
```
Response: `BatchExecutionResponse`

#### CancelBuild
Cancels a currently-running build (no-op if not `building`).
```json
{ "type": "CancelBuild", "params": { "build": "<id-or-name>" } }
```
Response: `Update`

### Repo Actions

#### CloneRepo
Clones the repo on its attached `server_id`.
```json
{ "type": "CloneRepo", "params": { "repo": "<id-or-name>" } }
```
Response: `Update`

#### BatchCloneRepo
Clones multiple repos matching `pattern`.
```json
{ "type": "BatchCloneRepo", "params": { "pattern": "foo-*\nextra-repo-1, extra-repo-2" } }
```
Response: `BatchExecutionResponse`

#### PullRepo
Pulls the repo on its attached `server_id`.
```json
{ "type": "PullRepo", "params": { "repo": "<id-or-name>" } }
```
Response: `Update`

#### BatchPullRepo
Pulls multiple repos matching `pattern`.
```json
{ "type": "BatchPullRepo", "params": { "pattern": "foo-*\nextra-repo-1, extra-repo-2" } }
```
Response: `BatchExecutionResponse`

#### BuildRepo
Builds the repo using its attached `builder_id`.
```json
{ "type": "BuildRepo", "params": { "repo": "<id-or-name>" } }
```
Response: `Update`

#### BatchBuildRepo
Builds multiple repos matching `pattern`.
```json
{ "type": "BatchBuildRepo", "params": { "pattern": "foo-*\nextra-repo-1, extra-repo-2" } }
```
Response: `BatchExecutionResponse`

#### CancelRepoBuild
Cancels a currently-running repo build (no-op if not `building`).
```json
{ "type": "CancelRepoBuild", "params": { "repo": "<id-or-name>" } }
```
Response: `Update`

### Stack Actions

#### DeployStack
```json
{ "type": "DeployStack", "params": { "stack": "<id-or-name>", "services": [], "stop_time": null } }
```
Response: `Update`

#### StartStack
```json
{ "type": "StartStack", "params": { "stack": "<id-or-name>", "services": [] } }
```
Response: `Update`

#### StopStack
```json
{ "type": "StopStack", "params": { "stack": "<id-or-name>", "stop_time": null, "services": [] } }
```
Response: `Update`

#### RestartStack
```json
{ "type": "RestartStack", "params": { "stack": "<id-or-name>", "services": [] } }
```
Response: `Update`

#### DestroyStack
```json
{ "type": "DestroyStack", "params": { "stack": "<id-or-name>", "services": [], "remove_orphans": false, "stop_time": null } }
```
Response: `Update`

#### DeployStackIfChanged
Only runs `docker compose up` if the deployed contents differ from the latest contents.
```json
{ "type": "DeployStackIfChanged", "params": { "stack": "<id-or-name>", "stop_time": null } }
```
Response: `Update`

#### PullStack
Pull images for all (or a subset of) services.
```json
{ "type": "PullStack", "params": { "stack": "<id-or-name>", "services": [] } }
```
Response: `Update`

#### PauseStack
```json
{ "type": "PauseStack", "params": { "stack": "<id-or-name>", "services": [] } }
```
Response: `Update`

#### UnpauseStack
```json
{ "type": "UnpauseStack", "params": { "stack": "<id-or-name>", "services": [] } }
```
Response: `Update`

#### RunStackService
Run a one-time command against a service using `docker compose run`.
```json
{
  "type": "RunStackService",
  "params": {
    "stack": "<id-or-name>",
    "service": "api",
    "command": ["sh", "-lc", "echo hello"],
    "no_tty": null,
    "no_deps": null,
    "detach": null,
    "service_ports": null,
    "env": null,
    "workdir": null,
    "user": null,
    "entrypoint": null,
    "pull": null
  }
}
```
Response: `Update`

---

## Write Module (`/write`)

### CreateDeployment
```json
{
  "type": "CreateDeployment",
  "params": {
    "name": "my-deployment",
    "config": {
      "server_id": "<server-id>",
      "image": { "image": "nginx", "tag": "latest" }
    }
  }
}
```

### UpdateDeployment
```json
{
  "type": "UpdateDeployment",
  "params": {
    "id": "<deployment-id>",
    "config": { ... }
  }
}
```

### DeleteDeployment
```json
{ "type": "DeleteDeployment", "params": { "id": "<deployment-id>" } }
```

### Build Management

#### CreateBuild
```json
{ "type": "CreateBuild", "params": { "name": "my-build", "config": { } } }
```
Response: `Build`

#### CopyBuild
```json
{ "type": "CopyBuild", "params": { "name": "my-build-copy", "id": "<build-id>" } }
```
Response: `Build`

#### UpdateBuild
```json
{ "type": "UpdateBuild", "params": { "id": "<build-id-or-name>", "config": { } } }
```
Response: `Build`

#### RenameBuild
```json
{ "type": "RenameBuild", "params": { "id": "<build-id-or-name>", "name": "new-build-name" } }
```
Response: `Update`

#### DeleteBuild
```json
{ "type": "DeleteBuild", "params": { "id": "<build-id-or-name>" } }
```
Response: `Build`

#### WriteBuildFileContents
Updates dockerfile contents (files-on-host or git-repo mode).
```json
{ "type": "WriteBuildFileContents", "params": { "build": "<id-or-name>", "contents": "..." } }
```
Response: `Update`

#### RefreshBuildCache
Refreshes cached remote hash/message/dockerfile contents.
```json
{ "type": "RefreshBuildCache", "params": { "build": "<id-or-name>" } }
```
Response: `NoData`

#### CreateBuildWebhook
```json
{ "type": "CreateBuildWebhook", "params": { "build": "<id-or-name>" } }
```
Response: `NoData`

#### DeleteBuildWebhook
```json
{ "type": "DeleteBuildWebhook", "params": { "build": "<id-or-name>" } }
```
Response: `NoData`

### Repo Management

#### CreateRepo
```json
{ "type": "CreateRepo", "params": { "name": "my-repo", "config": { } } }
```
Response: `Repo`

#### CopyRepo
```json
{ "type": "CopyRepo", "params": { "name": "my-repo-copy", "id": "<repo-id>" } }
```
Response: `Repo`

#### UpdateRepo
```json
{ "type": "UpdateRepo", "params": { "id": "<repo-id>", "config": { } } }
```
Response: `Repo`

#### RenameRepo
```json
{ "type": "RenameRepo", "params": { "id": "<repo-id-or-name>", "name": "new-repo-name" } }
```
Response: `Update`

#### DeleteRepo
```json
{ "type": "DeleteRepo", "params": { "id": "<repo-id-or-name>" } }
```
Response: `Repo`

#### RefreshRepoCache
Refreshes cached latest hash/message.
```json
{ "type": "RefreshRepoCache", "params": { "repo": "<id-or-name>" } }
```
Response: `NoData`

#### CreateRepoWebhook
```json
{ "type": "CreateRepoWebhook", "params": { "repo": "<id-or-name>", "action": "Pull" } }
```
Response: `NoData`

#### DeleteRepoWebhook
```json
{ "type": "DeleteRepoWebhook", "params": { "repo": "<id-or-name>", "action": "Pull" } }
```
Response: `NoData`

### Stack Management

#### CreateStack
```json
{
  "type": "CreateStack",
  "params": {
    "name": "my-stack",
    "config": {
      "server_id": "<server-id>",
      "project_name": "my-stack",
      "files_on_host": true,
      "run_directory": "/opt/stacks/my-stack",
      "file_paths": ["compose.yaml"]
    }
  }
}
```
Response: `CreateStackResponse` (a `Stack`)

#### UpdateStack
```json
{
  "type": "UpdateStack",
  "params": {
    "id": "<stack-id>",
    "config": {
      "auto_pull": true,
      "poll_for_updates": true
    }
  }
}
```
Response: `UpdateStackResponse` (a `Stack`)

#### DeleteStack
```json
{ "type": "DeleteStack", "params": { "id": "<stack-id>" } }
```
Response: `DeleteStackResponse` (a `Stack`)

#### RefreshStackCache
Refreshes cached compose/state data.
```json
{ "type": "RefreshStackCache", "params": { "stack": "<id-or-name>" } }
```
Response: `Update`

#### WriteStackFileContents
Writes stack compose file contents for stacks managed by Komodo.
```json
{ "type": "WriteStackFileContents", "params": { "stack": "<id-or-name>", "file_contents": "..." } }
```
Response: `Update`

---

## Data Models

### Server
```dart
{
  "id": "string",
  "name": "string",
  "description": "string?",
  "tags": ["string"],
  "config": {
    "address": "string",
    "port": int?,
    "enabled": bool
  }
}
```

### ServerState
- `Ok` - Server is healthy
- `NotOk` - Server has issues
- `Disabled` - Server is disabled
- `Unknown` - State unknown

### SystemStats
```dart
{
  "cpu_perc": double,      // CPU percentage
  "mem_total_gb": double,  // Total memory in GB
  "mem_used_gb": double,   // Used memory in GB
  "disk_total_gb": double, // Total disk in GB
  "disk_used_gb": double   // Used disk in GB
}
```

### Deployment
```dart
{
  "id": "string",
  "name": "string",
  "description": "string?",
  "tags": ["string"],
  "config": {
    "server_id": "string",
    "image": { "image": "string", "tag": "string?" },
    "restart": "string?",
    "network": "string?",
    "ports": [{ "local": "string", "container": "string" }],
    "volumes": [{ "local": "string", "container": "string" }],
    "environment": [{ "variable": "string", "value": "string" }]
  }
}
```

### DeploymentState (Container State)
- `Running`
- `Restarting`
- `Exited`
- `Paused`
- `NotDeployed`
- `Unknown`

### BuildActionState
Returned by `GetBuildActionStateResponse`.
```json
{ "building": false }
```

### RepoActionState
Returned by `GetRepoActionStateResponse`.
```json
{ "cloning": false, "pulling": false, "building": false, "renaming": false }
```

### BuildQuery
Used by `ListBuilds` / `ListFullBuilds`.
```json
{ "builder_ids": [], "repos": [], "built_since": 0 }
```

### RepoQuery
Used by `ListRepos` / `ListFullRepos`.
```json
{ "repos": [] }
```

### BuildListItemInfo
Returned on `ListBuildsResponse` items in `info`.
```json
{
  "state": "Building | Ok | Failed | Unknown",
  "last_built_at": 0,
  "version": { "...": "Version" },
  "builder_id": "string",
  "files_on_host": false,
  "dockerfile_contents": false,
  "linked_repo": "string",
  "git_provider": "string",
  "repo": "string",
  "branch": "string",
  "repo_link": "string",
  "built_hash": null,
  "latest_hash": null,
  "image_registry_domain": null
}
```

### RepoListItemInfo
Returned on `ListReposResponse` items in `info`.
```json
{
  "server_id": "string",
  "builder_id": "string",
  "last_pulled_at": 0,
  "last_built_at": 0,
  "git_provider": "string",
  "repo": "string",
  "branch": "string",
  "repo_link": "string",
  "state": "Unknown | Ok | Failed | Cloning | Pulling | Building",
  "cloned_hash": null,
  "cloned_message": null,
  "built_hash": null,
  "latest_hash": null
}
```

### StackListItemInfo
Used on `ListStacksResponse` / `GetStacksSummaryResponse`.
```json
{
  "server_id": "string",
  "state": "string",
  "status": "string",
  "project_name": "string"
}
```

### StackService
Returned by `ListStackServicesResponse`.
```json
{
  "service": "string",
  "image": "string",
  "container": null,
  "update_available": false
}
```

### StackConfig (Compose Configuration)
Returned on `GetStackResponse.config` and used when creating/updating stacks.
```json
{
  "server_id": "string",
  "links": ["string"],
  "project_name": "string",

  "auto_pull": false,
  "run_build": false,
  "poll_for_updates": false,
  "auto_update": false,
  "auto_update_all_services": false,
  "destroy_before_deploy": false,
  "skip_secret_interp": false,

  "linked_repo": "string",
  "git_provider": "string",
  "git_https": true,
  "git_account": "string",
  "repo": "string",
  "branch": "string",
  "commit": "string",
  "clone_path": "string",
  "reclone": false,

  "webhook_enabled": false,
  "webhook_secret": "string",
  "webhook_force_deploy": false,

  "files_on_host": false,
  "run_directory": "string",
  "file_paths": ["compose.yaml"],
  "env_file_path": ".env",
  "additional_env_files": [],
  "config_files": [],

  "send_alerts": false,
  "registry_provider": "string",
  "registry_account": "string",

  "pre_deploy": { "...": "SystemCommand" },
  "post_deploy": { "...": "SystemCommand" },
  "extra_args": [],
  "build_extra_args": [],
  "ignore_services": [],

  "file_contents": "string",
  "environment": "string"
}
```

### Log
Returned by `GetStackLogResponse` and `SearchStackLogResponse`.
```json
{
  "stage": "string",
  "command": "string",
  "stdout": "string",
  "stderr": "string",
  "success": true,
  "start_ts": 0,
  "end_ts": 0
}
```

### Update
Most `/execute` actions respond with an `Update` record describing the started/completed operation.
```json
{
  "_id": { "$oid": "..." },
  "operation": "string",
  "start_ts": 0,
  "success": true,
  "operator": "string",
  "target": { "...": "ResourceTarget" },
  "logs": [/* Log */],
  "end_ts": null,
  "status": "string",
  "version": { "...": "Version" },
  "commit_hash": "string",
  "other_data": "string",
  "prev_toml": "string",
  "current_toml": "string"
}
```

---

## Error Response Format

```json
{
  "error": "Error message",
  "trace": ["stack", "trace", "lines"]
}
```

---

## API Documentation Sources

- Komodo Intro: https://komo.do/docs/intro
- API Overview: https://komo.do/docs/ecosystem/api
- Rust Client Docs: https://docs.rs/komodo_client/latest/komodo_client/api/index.html
  - Read module: https://docs.rs/komodo_client/latest/komodo_client/api/read/index.html
  - Execute module: https://docs.rs/komodo_client/latest/komodo_client/api/execute/index.html
  - Write module: https://docs.rs/komodo_client/latest/komodo_client/api/write/index.html
