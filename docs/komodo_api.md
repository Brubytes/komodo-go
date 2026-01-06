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

### Stacks

#### ListStacks
```json
{ "type": "ListStacks", "params": { "query": "" } }
```

#### GetStack
```json
{ "type": "GetStack", "params": { "stack": "<id-or-name>" } }
```

#### ListStackServices
```json
{ "type": "ListStackServices", "params": { "stack": "<id-or-name>" } }
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

### Stack Actions

#### DeployStack
```json
{ "type": "DeployStack", "params": { "stack": "<id-or-name>" } }
```

#### StartStack
```json
{ "type": "StartStack", "params": { "stack": "<id-or-name>" } }
```

#### StopStack
```json
{ "type": "StopStack", "params": { "stack": "<id-or-name>" } }
```

#### RestartStack
```json
{ "type": "RestartStack", "params": { "stack": "<id-or-name>" } }
```

#### DestroyStack
```json
{ "type": "DestroyStack", "params": { "stack": "<id-or-name>" } }
```

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
