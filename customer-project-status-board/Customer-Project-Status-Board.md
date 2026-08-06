# Customer Project Status Board

Quick snapshot of the current user's cloud project portfolio,
cross-referenced with today's calendar and recent emails to produce a prioritized daily TODO.

## Parameters

This command accepts optional arguments:

```
/Customer-Project-Status-Board [customer names | fresh]
```

**Examples:**
- `/Customer-Project-Status-Board NEOBPO` — searches portal for that specific customer (skips interactive prompt)
- `/Customer-Project-Status-Board "NEOBPO, Dotz"` — multiple customers (skips interactive prompt)
- `/Customer-Project-Status-Board fresh` — force full refresh, ignoring cache (sets `FORCE_REFRESH=true`)

### Interactive mode — ask before Step 0 (when no inline argument is provided)

When invoked **without arguments**, always ask the user before doing anything:

```
Como deseja buscar os projetos?

[1] Meus projetos assignados (personal dashboard)
[2] Por cliente (informe o nome)
```

If user chooses **[1]**: set `CUSTOMER_FILTER=""` and proceed to Step 0.

If user chooses **[2]**: immediately show the following examples, then wait for input:

```
Digite o(s) nome(s) do(s) cliente(s). Exemplos:

  NEOBPO
  Dotz
  "NEOBPO, Dotz, ADEMICON"

Nomes parciais são aceitos — a busca é case-insensitive.
```

Set the typed value as `CUSTOMER_FILTER` and proceed to Step 0.

**Parameter handling:**
- If argument is `fresh` → set `FORCE_REFRESH=true`, `CUSTOMER_FILTER=""`, skip interactive prompt, proceed to Step 0
- If other argument provided inline → store as `CUSTOMER_FILTER`, skip interactive prompt, proceed to Step 0
- If `CUSTOMER_FILTER=""` (option 1) → csb-01-portal uses `__my_dashboard`
- If `__my_dashboard` returns 0 projects → **stop and show:**
  ```
  ⚠️ Nenhum projeto encontrado assignado a você.

  Para buscar por nome de cliente, escolha a opção [2] ou re-execute com o nome do cliente. Exemplos:

    /Customer-Project-Status-Board NEOBPO
    /Customer-Project-Status-Board "Bichara Advogados"
    /Customer-Project-Status-Board "NEOBPO, Dotz, ADEMICON"

  Nomes parciais são aceitos — a busca é case-insensitive.
  ```
  Do NOT fall back to full portfolio automatically.

## Architecture

This command is an orchestrator. It delegates each concern to a focused sub-skill:

| Module | Responsibility | Output |
|---|---|---|
| csb-00-init | Setup, paths, cache check | Session variables |
| csb-01-portal | Cloud Reporting portal → projects | `data/portfolio.json` |
| csb-02-itsm | ServiceNow cases + WCR (Playwright) | `data/itsm.json` |
| csb-03-comms | Graph API calendar + email | `data/comms.json` |
| csb-04-crossref | Pseudonymize + cross-reference + alerts | `data/crossref.json` |
| csb-05-html | De-pseudonymize + render HTML | `*.html` file |
| csb-06-finalize | Log + Teams notification + open browser | Done |

## Execution

### Step 0 — Initialize (always first)

Run **csb-00-init**:
- Resolve `OUTPUT_DIR`, `DATA_DIR`, `USER_ID`, `SESSION_ID`
- Validate write permissions — abort if directory not writable
- Check cache freshness (portfolio.json < 4h → skip portal fetch; `fresh` arg → força rebusca)
- Write `progress.txt`: `STEP:0:7:Initializing...`

---

### Steps 1 + 2 + 3 — Fetch in parallel (start all three simultaneously)

These three modules are fully independent. Start all at the same time — do NOT wait for one before starting the others.

**csb-01-portal** → `data/portfolio.json`
- If cache valid (from Step 0): skip fetch, reuse existing file
- Otherwise: fetch from Cloud Reporting portal via Playwright
- On failure: use `last_known_portfolio.json` → then hardcoded baseline
- **Project filtering when CUSTOMER_FILTER is set (option 2):**
  - For each project found, inspect SAP Contacts from the HPI detail page
  - **Step 1 — try personal filter first:** collect all projects where `USER_ID` (e.g. I555748) is listed in SAP Contacts (any role) → tag `"myProject": true`
  - **Step 2 — fallback if Step 1 returns 0 projects:** collect all projects that have at least one contact with role containing "P&E Solution Architect" → tag `"myProject": false`
  - **Exclude** projects where neither condition is met
  - Never mix Step 1 and Step 2 results: if Step 1 finds any projects, do NOT include Step 2 projects
- **SAP Contacts display in HTML:**
  - If `myProject: true` → show **only the running user** (USER_ID) in the team section
  - If `myProject: false` (fallback mode) → show all P&E Solution Architects found in SAP Contacts
- **HTML rendering scope — applies to ALL tabs (Dashboard, Projetos, and all others):**
  - Show only the filtered set of projects (result of Step 1 or Step 2 above)
  - Never render projects outside the filtered set in any tab

**csb-02-itsm** → `data/itsm.json`
- Fetch open cases via Playwright (batched query, all customers)
- Fetch WCR in same browser session (reuse — do not open new browser)
- On failure: store empty arrays, mark `source: "unavailable"`

**csb-03-comms** → `data/comms.json`
- Fetch calendar (today) and emails (last 7 days) via Graph API in parallel
- On partial failure: continue with available data

Wait for all three to complete before proceeding.

---

### Step 4 — Cross-reference (after Steps 1+2+3)

Run **csb-04-crossref**:
- Validate all three input files exist
- Pseudonymize all collected data (SAP Data Privacy Policy — mandatory)
- Cross-reference projects × calendar × email
- Detect go-live date changes vs `last_known_portfolio.json`
- Compute alerts, next actions, prioritized TODO, meeting prep
- Write `data/crossref.json` and `data/mapping.json`

---

### Step 5 — Render HTML (after Step 4)

Run **csb-05-html**:
- De-pseudonymize crossref data
- Resolve output filename with sequence number
- Render 7-tab HTML report with SAP Fiori design
- Sanitize all scraped content (XSS prevention)
- Save HTML file
- Print dashboard snapshot to chat

---

### Step 6 — Finalize (after Step 5)

Run **csb-06-finalize**:
- Write one-line entry to `execution_log.txt`
- Open HTML in browser using PowerShell `Invoke-Item` (with `dangerouslyDisableSandbox: true`):
  ```bash
  powershell.exe -Command "Invoke-Item '<HTML_FILE_PATH>'"
  ```
  Do NOT use `cmd.exe /c start` — it fails silently in this environment.
- Write `STEP:7:7:DONE` to `progress.txt`

## Privacy & Data Protection (LGPD/GDPR)

**Never include:** personal email/phone, health/financial data, verbatim private messages.
**Only include:** project status, risks, decisions, actions — people by name + role only.
When in doubt, omit. If content was suppressed, append: `⚠️ Some information was omitted to comply with LGPD/GDPR.`
