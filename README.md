# OpsChat

Real-time chat and server management for DevOps teams.

## Problem

- SSH into multiple servers manually is slow and error-prone
- No visibility into who ran what command and when
- Team communication scattered across Slack, terminals, and tickets
- Difficult to onboard new team members to server access

## Solution

OpsChat combines team chat with server management:

- Run commands on multiple servers from a single UI
- Full audit trail of all operations
- Role-based access control (admin vs read-only)
- Real-time collaboration with Discord-style channels

## Features

- **Chat Channels** - #general, #alerts, #deployments, auto-created per server
- **Server Management** - SSH via password or private key
- **Bot Commands** - `/status`, `/disk`, `/r server cmd`
- **Audit Dashboard** - Who did what, when, with statistics
- **RBAC** - Admin and user roles

## Quick Start

```bash
git clone <repo>
cd ops_chat

cp .env.example .env
# Edit .env: set SECRET_KEY_BASE and passwords

docker-compose up -d
```

## Environment Variables

```bash
SECRET_KEY_BASE=       # Run: mix phx.gen.secret
ADMIN_USERNAME=admin
ADMIN_PASSWORD=        # Strong password
USER_USERNAME=devops
USER_PASSWORD=         # Strong password
```

## Pages

| URL | Description |
|-----|-------------|
| `/login` | Authentication |
| `/chat` | Chat with channels |
| `/servers` | Server management |
| `/audit` | Audit logs (admin only) |

## Bot Commands

```text
/help              - Show help
/status            - System status
/disk, /memory     - Resource usage
/servers           - List servers
/r <server> <cmd>  - Run remote command
```

## Tech Stack

- Elixir + Phoenix LiveView
- SQLite
- Erlang :ssh (built-in, no external deps)
- Tailwind + DaisyUI
