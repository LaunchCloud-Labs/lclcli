# LaunchCore Command (`lc`)

> Product #1 of 11 in the LaunchCloud Labs stack  
> CLI-First · Zero-Trust · Production-Grade

```
██╗      ██████╗
██║     ██╔════╝
██║     ██║
██║     ██║
███████╗╚██████╗
╚══════╝ ╚═════╝

LaunchCore Command  v1.0.0 "Midnight"
```

## Overview

`lc` is an interactive Ruby REPL and the **Logic Engine** for the entire LaunchCloud Labs platform.  
The Sinatra web interface is a visual mirror — every button executes `lc [command] --json` via `Open3`.

## Requirements

- Ruby 3.1+
- SQLite 3
- Sendmail (for transactional email)

## Installation

```bash
cd /path/to/lclcli
bundle install
```

### Run Setup (first time)

```bash
exe/lc setup
```

This will:
1. Create `LCL_ROOT/data/` directory
2. Initialize the SQLite database and apply the schema
3. Generate RS256 JWT keypair at `~/.lcl_keys/`

## Usage

### Interactive REPL

```bash
exe/lc
```

Or after gem install:

```bash
lc
```

### Single-Shot Mode

```bash
lc /status
lc /auth/login
lc /auth/signup
lc /voice --sub=status
lc /neobank --sub=balance
lc /arbiter --sub=chat --message="Hello, AI"
```

### JSON Output (for scripting / Sinatra bridge)

```bash
lc /status --json
lc /auth/login --json
```

## Slash Commands

| Command | Description |
|---------|-------------|
| `/auth/login` | Interactive login (RS256 JWT, persisted to `~/.lcl_session`) |
| `/auth/signup` | Account creation with placeholder payment |
| `/auth/logout` | Revoke JWT and clear session |
| `/auth/invite` | Generate invite code (L2+ required) |
| `/settings` | Account settings menu |
| `/settings/2fa` | Enable TOTP 2FA (upgrades to L2) |
| `/settings/kyc` | Submit KYC (upgrades to L3) |
| `/settings/password` | Change password |
| `/settings/profile` | Update profile |
| `/status` | System status + DB stats |
| `/help` | Full command reference |

## The 11 Products

| # | Command | Product | Min Level |
|---|---------|---------|-----------|
| 1 | `/voice` | LaunchCore Voice (Telnyx VoIP) | L1 |
| 2 | `/tunnel` | AmneziaWG VPN Tunnel | L1 |
| 3 | `/portal` | Operations Hub | L1 |
| 4 | `/meetings` | Neural Meetings (Jitsi/8x8) | L2 |
| 5 | `/workforce` | Workforce Platform | L2 |
| 6 | `/scheduler` | Kill-Switch Scheduler | L2 |
| 7 | `/neobank` | NeoBank (Mercury+Lithic) | L3 |
| 8 | `/brinkspay` | BrinksPay BNPL (Bloom Credit) | L3 |
| 9 | `/tradeshield` | TradeShield (CRS Metro 2) | L3 |
| 10 | `/stophold` | StopHold JIT Travel | L4 |
| 11 | `/arbiter` | Arbiter AI Router | L2 |

## 4-Tier Auth Levels

| Level | Name | Requirement |
|-------|------|-------------|
| L1 | Password Verified | Valid password login |
| L2 | 2FA Verified | TOTP enabled + verified |
| L3 | KYC Verified | Identity verification approved |
| L4 | NeoBank Ready | L1+L2+L3 + 30-day active account |

## Web Interface

The Sinatra app runs at `LCL_ROOT` (default: `/home/Gcolonna/public_html/lclcli`).

```bash
cd sinatra
bundle exec puma -C config.ru
```

Or via Rack:

```bash
rackup sinatra/config.ru
```

Features:
- Login / Signup mirrors CLI auth
- Dashboard shows 11-product grid with auth-level gating
- **Live Terminal Console** overlay (`>_` button or backtick `` ` ``)
- Every product tile executes `lc /<product> --json` via `/api/exec`

## Architecture

```
                ┌─────────────────┐
                │   exe/lc REPL   │
                └────────┬────────┘
                         │
              ┌──────────▼──────────┐
              │  Dispatcher (REPL)  │
              └──────────┬──────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼────┐    ┌─────▼─────┐   ┌────▼────────┐
    │  Auth   │    │ Products  │   │  Settings   │
    │ (JWT)   │    │ (11)      │   │             │
    └────┬────┘    └─────┬─────┘   └─────────────┘
         │               │
    ┌────▼───────────────▼────┐
    │   SQLite Database       │
    │   (LCL_ROOT/data/       │
    │    launchcore.db)       │
    └─────────────────────────┘
              ▲
              │  Open3.capture3("lc [cmd] --json")
    ┌─────────┴─────────┐
    │  Sinatra Web App  │
    │  (Web Mirror)     │
    └───────────────────┘
```

## Configuration

| Env Var | Default | Description |
|---------|---------|-------------|
| `LCL_ROOT` | `/home/Gcolonna/public_html/lclcli` | Root directory |
| `LC_SESSION_SECRET` | Random | Sinatra session cookie secret |
| `LC_BIN` | `../../exe/lc` | Path to `lc` binary (for Sinatra) |

## Development

```bash
# Run tests
bundle exec rspec

# Lint
bundle exec rubocop

# Setup DB
bundle exec rake setup

# All checks
bundle exec rake
```

## Security

- RS256 JWT stored at `~/.lcl_session` (chmod 600)
- JWT revocation via JTI registry in SQLite
- Bcrypt cost factor 12 for password hashing
- 5-attempt lockout (15 minutes) on failed logins
- TOTP via ROTP (RFC 6238 compliant)
- Sinatra command whitelist prevents auth bypass via `/api/exec`
- `rack-protection` enabled on all web routes

## LaunchCloud Labs

- Website: [launchcloudlabs.com](https://launchcloudlabs.com)
- Product Architecture: CLI-First, Lark-Backed, Zero-Trust

---

*Built with LaunchCore Command v1.0.0 "Midnight"*
