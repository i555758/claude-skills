# csb-01-portal — Fetch Project Portfolio

Fetches active project data from the SAP Cloud Reporting portal via Playwright.
Writes result to `data/portfolio.json`. Falls back to last known data or hardcoded baseline if portal is unavailable.

## Input

- `CACHE_VALID` from csb-00-init — if true, skip fetch and use existing `data/portfolio.json`
- `OUTPUT_DIR` / `DATA_DIR` from csb-00-init

## Output

`data/portfolio.json`:
```json
{
  "projects": [],
  "source": "portal | cache | last_known | baseline",
  "fetchedAt": "ISO timestamp"
}
```

## Steps

### 1. Check cache — skip fetch if valid

If `CACHE_VALID=true` (from csb-00-init), skip all steps below and output:
```
⚡ Portfolio cache is fresh — skipping portal fetch
```
Otherwise proceed.

### 2. Authenticate and navigate

Authenticate if needed:
```
sap_authenticate: https://reporting.ondemand.com
```

**Choose URL based on `CUSTOMER_FILTER`:**

- If `CUSTOMER_FILTER=""` (no argument passed) → use personal dashboard:
  ```
  https://reporting.ondemand.com/sap/crp/cdo?type=crp_db&db_id=__my_dashboard
  ```
  This page lists project cards. Extract project IDs from the card links (pattern: `id=NNNNNN`).
  If 0 project cards found → do NOT fall back to full list; signal the orchestrator to stop and ask the user for a customer name.

- If `CUSTOMER_FILTER` is set → use the portal search to find the customer first:
  ```
  https://reporting.ondemand.com/sap/crp/cdo?query={CUSTOMER_FILTER}&type=crp_search
  ```
  From the search results, extract customer IDs from the Customers table (links with pattern `type=CRP_C&id=NNNNN`).
  Keep only customers whose name matches `CUSTOMER_FILTER` (case-insensitive, partial match).
  For each matched customer, navigate to their HPI project page:
  ```
  https://reporting.ondemand.com/sap/crp/cdo?type=CRP_HPI&list=20&id={PROJECT_ID}
  ```
  If no customers found → warn: `⚠️ No projects found matching: {CUSTOMER_FILTER}`

Wait up to **5 seconds** for the project table to load.
Note: the portal is a JS-only SPA that frequently returns an empty body in the MCP Playwright environment. Fail fast and use the fallback — do not wait longer.

**Failure handling:**
- Redirect to login → re-authenticate once, then retry
- Timeout / network error → use fallback with warning: `⚠️ Portal unavailable`

### 3. Extract project data

**Mode A — Personal dashboard (`CUSTOMER_FILTER=""`):**

The My Dashboard page shows project cards, not a table. Extract project IDs from card links:
```js
() => {
  const links = document.querySelectorAll('a[href*="type=CRP_HPI"][href*="id="]');
  const projects = [];
  links.forEach(link => {
    const idMatch = link.href.match(/[?&]id=(\d+)/);
    const name = link.innerText.trim();
    if (idMatch && name) {
      projects.push({ id: idMatch[1], name });
    }
  });
  return projects;
}
```
This returns a list of `{ id, name }`. Then for each project, navigate to its detail page to extract full data (stage, status, partner, go-live, rollout country — see Mode B below).

**Mode B — Customer filter (`CUSTOMER_FILTER` set):**

After navigating to the project detail page (`type=CRP_HPI&list=20&id={PROJECT_ID}`), extract:
```js
() => {
  const get = label => {
    const rows = document.querySelectorAll('table tr');
    for (const row of rows) {
      const cells = row.querySelectorAll('td');
      if (cells.length >= 2 && cells[0].innerText.trim() === label)
        return cells[1].innerText.trim();
    }
    return '';
  };
  return {
    name:           document.querySelector('h1')?.innerText.replace(/\(Project \d+\).*/, '').trim() || '',
    crmId:          get('CRM ID') || get('CRM Account ID') || get('CRM Customer ID') || '',
    stage:          get('Project Stage'),
    status:         get('Project Status'),
    phase:          get('Current Activate Phase').replace(/[◼◻]/g, '').trim(),
    goLive:         get('Next Go-Live') || get('Planned Business Go-Live'),
    initialGoLive:  get('Initial Planned Business Go-Live'),
    partner:        get('Main Partner').replace(/\(.*\)/, '').trim(),
    partnerStatus:  get('Partner Status'),
    waveNumber:     (() => {
      // Count wave sections on the page (h4/link containing "Wave N [ID:")
      const waves = document.querySelectorAll('a[href*="anchor_p_wave_"]');
      return waves.length || 1;
    })()
  };
}
```

Map portal color text: `Green` → `Green`, `Yellow` / `At Risk` → `Yellow`, `Red` → `Red`, `On Hold` → `On Hold`.

Exclude projects where `stage` is `Complete` or `Completed`.

### 4. Pseudonymize and save to data/portfolio.json

**Before writing to disk**, pseudonymize all sensitive fields (project names, partner names, CRM IDs):

```
POST https://anonymization-proxy.cfapps.eu12.hana.ondemand.com/pseudonymize
Body: { "text": "<all project names + partner names + CRM IDs concatenated>" }
```

Retry up to **3 times** with exponential backoff (200ms, 600ms, 1200ms) if the proxy is unreachable.

- If proxy responds: replace real values in the projects array with tokens. Store the returned `mapping` in memory as `PORTFOLIO_MAPPING`.
- If proxy fails after 3 retries: log `pseudonymize=unavailable`, write data without substitution, add a note to the HTML footer: `⚠️ Pseudonymização indisponível — dados gravados sem anonimização.`

```bash
OUTPUT_DIR="${USERPROFILE:-$HOME}/Customer-Project-Status-Board"
DATA_DIR="$OUTPUT_DIR/data"
printf '%s\n' "STEP:1:7:Portal data loaded" > "$OUTPUT_DIR/progress.tmp" && mv "$OUTPUT_DIR/progress.tmp" "$OUTPUT_DIR/progress.txt"
```

Write the (pseudonymized) projects array to `$DATA_DIR/portfolio.json` with `source` and `fetchedAt` fields.

- If projects came from `__my_dashboard` URL: `source: "portal"`
- If projects came from customer search + detail pages: `source: "portal_search"`

Also save a copy as `$DATA_DIR/last_known_portfolio.json` — this is the permanent fallback for future runs when portal is unavailable.

### 5. Fallback — last known data

If portal failed, check if `data/last_known_portfolio.json` exists. If yes, use it with `source: "last_known"`.

If neither portal nor last_known is available, use the hardcoded baseline below with `source: "baseline"`.
Add warning banner: `⚠️ Portal unavailable — using cached baseline`.

**Hardcoded baseline (last resort only):**

> Note: `crmId` column contains the ONE 360 CRM Account ID. Leave blank (`—`) if unknown — it will be populated from the portal at runtime.

| Project | ID | CRM ID | Stage | Status | Phase | Go-Live | Partner | Partner Status | Solution Architect |
|---|---|---|---|---|---|---|---|---|---|
| NEOBPO | 227881 | — | Live | Green | Run | 2026-01-05 | Tivit | Red | — |
| Bichara Advogados | 232351 | — | Implementing | Green | Realize | 2026-07-31 | NTT DATA | Green | — |
| SL Cereais | 246994 | — | Implementing | Red | Deploy | 2026-06-01 | Ramo Sistemas | Red | — |
| Persianas Canet | 266942 | — | Live | Green | Run | 2026-04-06 | Axento | Green | — |
| Omni Aviation | 254355 | — | Implementing | Green | Deploy | 2026-05-02 | Exed Consulting | Green | — |
| Cartão de Todos | 273961 | — | On Hold | On Hold | Explore | — | Seidor | Not Started | — |
| Dotz S.A. | 277849 | — | Implementing | Green | Realize | 2026-06-30 | Action Systems | Not Started | — |
| Siderúrgica São Joaquim | 278741 | — | Not Started | Not Started | Prepare | — | Inetum | — | — |
| ADEMICON | 282178 | — | Implementing | Green | Prepare | 2026-08-03 | Numen IT | Green | — |
| EPR Participações | TBD | — | Implementing | Green | Prepare | TBD | Exed Consulting | Green | — |
