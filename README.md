# ShogunX

ShogunX is our AI-powered trading bot. It runs on **MetaTrader 4 (MT4)** via an Expert Advisor (EA) for fast tick-to-API response, and connects to this Rails API backend for decision-making, risk checks, and order responses.

## ShogunX directions

**OpenAI suggests.**  
**Rails approves.**  
**MT4 executes.**  
**Rails records everything.**

| Principle | Meaning |
|-----------|---------|
| OpenAI suggests | The Brain proposes a trade (direction, size, stops) from market context. It does not place orders or bypass checks. |
| Rails approves | The API runs auth, risk limits, and policy. Only an approved (or explicit hold/reject) response goes back to the EA. |
| MT4 executes | The EA sends signals and, when told to, places trades on the broker terminal. No AI or Rails code runs inside MT4. |
| Rails records everything | Signals, proposals, approvals, rejections, and execution outcomes are persisted and auditable in this backend. |

Nothing trades on the broker until Rails approves it. Nothing is forgotten on the server side.

## Broker account (FBS)

Log in through **MT4 only** — the EA does not store broker login or password. ShogunX talks to your Rails API; MT4 talks to FBS when placing trades.

1. Install MT4 from FBS (or use your existing terminal).
2. **File → Login to Trade Account** (or the login dialog on startup).
3. Enter your FBS credentials:
   - **Server:** `FBS-Real-7` (real) — use the demo server from FBS if you are testing on demo first.
   - **Login** and **Password:** from the FBS client area (never commit these or paste them into this repo).
4. Confirm the chart shows your balance in the **Terminal** tab, then attach the ShogunX EA.

**Security:** Keep broker passwords out of git, `.env`, and the EA source. If a password was shared in chat or a screenshot, change it in the FBS cabinet and use the new one in MT4 only.

## MT4 installation

Source: [`mt4/ShogunX.mq4`](mt4/ShogunX.mq4)

1. Copy `mt4/ShogunX.mq4` into your MT4 data folder under `MQL4/Experts/` (or open it in MetaEditor and compile there).
2. Compile in MetaEditor (**Compile** or F7) to produce `ShogunX.ex4`.
3. In MT4, open **Navigator → Expert Advisors** and attach **ShogunX** to a chart.
4. Enable **AutoTrading** in the MT4 toolbar.
5. **Tools → Options → Expert Advisors** — enable *Allow WebRequest for listed URL* and add **`http://127.0.0.1`** (no `:3000` — MT4 only allows ports **80** / **443**). **Restart MT4** after changing this list.
6. Run **`make upd`** — exposes the API on host port **80** (mapped to Rails 3000 in Docker). EA inputs: **ApiHost** `127.0.0.1`, **ApiPort** `80`.
7. Signals URL becomes `http://127.0.0.1/api/v1/signals` (browser/curl on port 3000 still works: `http://localhost:3000`).

   **MT4 on Windows/VM, API on Mac:** set **ApiHost** to your Mac LAN IP (`make mt4-host`), whitelist `http://192.168.x.x`, keep **ApiPort** `80`.

7. **IntervalSeconds** defaults to **14400** (4 hours). Use **3** for local testing only.

### EA behavior

- Calls the API once when attached, then every **IntervalSeconds** (default **4 hours**) via an MT4 timer (works even when ticks are sparse).
- **POST**s a market snapshot JSON (fields match `MarketSnapshot` on Rails):

  ```json
  {
    "symbol": "EURUSD",
    "timeframe": "H1",
    "price": 1.08500,
    "rsi": 55.25,
    "ema50": 1.08400,
    "ema200": 1.08200,
    "support": 1.08000,
    "resistance": 1.09000
  }
  ```

  `timeframe` is the chart period; `price` is **Bid**; `rsi` / `ema50` / `ema200` from built-in indicators; `support` / `resistance` are the lowest low and highest high over **SupportResistanceBars** (default 20).

- Logs HTTP status and the Rails JSON response (`status`, `snapshot_id`, `action`) in the **Experts** tab. Order execution from the response will be added once the full pipeline returns approved orders.

### Connect to local API

```bash
make upd
make status   # http://localhost:3000/up
```

With the EA on a chart and WebRequest allowed, you should see `Rails Response: {...}` in MT4 on each interval.

## Architecture

Flow matches [ShogunX directions](#shogunx-directions): suggest → approve → execute → record.

```
MT4 EA  →  POST signal
              ↓
         ShogunX Rails API  →  record signal
              ↓
         OpenAI Brain  →  suggestion (record proposal)
              ↓
         Risk / policy  →  approve or reject (record decision)
              ↓
         JSON order response  →  record outcome sent to EA
              ↓
         MT4 EA  →  execute on broker (if approved)
```

| Step | Component | Role |
|------|-----------|------|
| 1 | **MT4 EA** | Client on MT4. POSTs snapshots every **IntervalSeconds** (default 4h). Executes only approved orders. |
| 2 | **ShogunX Rails API** | Orchestrates the pipeline, approves or rejects, **records everything**, returns structured JSON to the EA. |
| 3 | **OpenAI Brain** | **Suggests** a trade action from context. Does not approve or execute. |
| 4 | **Risk Manager** | Part of Rails approval: limits, exposure, safety before any order is returned. |
| 5 | **Order response** | Approved, hold, or rejected payload for the EA. |
| 6 | **MT4** | **Executes** approved trades on the broker terminal. |

```mermaid
sequenceDiagram
    participant EA as MT4 EA
    participant API as ShogunX Rails API
    participant AI as OpenAI Brain
    participant Risk as Risk Manager

    EA->>API: Signal (market context)
    API->>API: Record signal
    API->>AI: Structured prompt
    AI-->>API: Suggestion
    API->>API: Record proposal
    API->>Risk: Approve?
    Risk-->>API: Approved / rejected
    API->>API: Record decision
    API-->>EA: Order response
    EA->>EA: Execute if approved
    API->>API: Record execution result
```

## Backend development

This repo is the ShogunX Rails API — the server-side backend for the trading bot. The MT4 EA is installed separately on MetaTrader 4.

**Requirements:** Docker, Docker Compose, Make

```bash
cp .env.example .env   # set SHOGUNX_API_KEY and OPENAI_API_KEY
make build
make upd               # start db + web in the background
make db-setup          # prepare the development database
make status            # verify http://localhost:3000/up
```

Common commands: `make logs`, `make console`, `make test`, `make down`.

### CI locally (RuboCop + RSpec)

After changing the `Gemfile`, install gems in Docker once:

```bash
make bundle
```

Then:

```bash
make rubocop                 # lint (auto-runs bundle install if gems are missing)
make rspec                   # full suite (Docker)
make rspec SPEC=spec/requests/api/v1/signals_spec.rb
make ci                      # rubocop then rspec
make test                    # alias for make rspec
```

GitHub Actions runs **RuboCop**, **RSpec**, and security scans on every push/PR.

Optional env vars: `APP_PORT` (default `3000`), `DB_PORT` (default `5433`).

## Configuration

| Variable | Description |
|----------|-------------|
| `SHOGUNX_API_KEY` | Planned: secret the MT4 EA will send as `X-ShogunX-Api-Key` (not in EA yet) |
| `OPENAI_API_KEY` | OpenAI API key for the Brain layer |
| `RAILS_MASTER_KEY` | Rails credentials key (auto-loaded from `config/master.key` in dev) |

## Tech stack

- Ruby 3.3.6 / Rails 8.1
- PostgreSQL 16
- Docker + Kamal for deployment
