# csb-02-itsm — Fetch Cases and WCR

Fetches open ServiceNow cases and WCR requests via Playwright (browser-based, reusing same session).
Writes result to `data/itsm.json`.

## Input

- `OUTPUT_DIR` / `DATA_DIR` / `USER_ID` from csb-00-init
- Project list from `data/portfolio.json` (for customer name matching)

## Output

`data/itsm.json`:
```json
{
  "cases": [],
  "wcr": [],
  "source": "live | partial | unavailable",
  "fetchedAt": "ISO timestamp"
}
```

## Steps

### 1. Authenticate

```
sap_authenticate: https://itsm.services.sap
```

### 2. Fetch cases — single batched query

Navigate to batched URL with all active project customer names:
```
https://itsm.services.sap/sn_customerservice_case_list.do?sysparm_query=state!=3^state!=6^state!=7^(account.nameCONTAINSNEOBPO^ORaccount.nameCONTAINSBichara Advogados^ORaccount.nameCONTAINSSL Cereais^ORaccount.nameCONTAINSPersianas Canet^ORaccount.nameCONTAINSOmni Aviation^ORaccount.nameCONTAINSCartao de Todos^ORaccount.nameCONTAINSDotz^ORaccount.nameCONTAINSSiderurgica Sao Joaquim^ORaccount.nameCONTAINSADEMICON^ORaccount.nameCONTAINSEPR Participacoes)&sysparm_view=
```

**IMPORTANT — URL pattern**: Use the direct `.do?` URL (without `now/nav/ui/classic/params/target/` wrapper).
The `now/nav` wrapper loads content inside a `MACROPONENT` shadow root, making it inaccessible to Playwright DOM queries.
The direct `.do?` URL renders the list in the main document and works correctly.

State codes (confirmed from ServiceNow choice list):
- `1` = New (open — do NOT exclude)
- `3` = Closed (exclude)
- `6` = Resolved (exclude)
- `7` = Cancelled (exclude)
- `10` = In progress (open — do NOT exclude)

**Timeout:** 5 seconds. If exceeded, proceed to fallback (Step 3).

**Parallel fallback pre-launch**: While the batched query is loading, immediately start the top-3 fallback queries (highest-risk projects — go-live < 60 days) in parallel, so they are ready if the batch times out. Cancel fallbacks if the batch succeeds within 5 seconds.

Extract rows:
```js
() => {
  const rows = Array.from(document.querySelectorAll('tbody tr'));
  const cases = [];
  rows.forEach(row => {
    const text = row.innerText;
    const rowText = text.substring(0, 500);
    const numMatch = text.match(/\d{6}\/\d{4}/);
    const csMatch = text.match(/CS\d+/);
    let priority = null;
    if (text.includes('1 - Critical') || text.includes('P1')) priority = 'P1';
    else if (text.includes('2 - High') || text.includes('P2')) priority = 'P2';
    else if (text.includes('3 - Moderate') || text.includes('P3')) priority = 'P3';
    else priority = 'P4';
    if (numMatch || csMatch) {
      cases.push({ number: numMatch?.[0] || csMatch?.[0], priority, rowText });
    }
  });
  return { count: cases.length, cases };
}
```

**Assign cases to projects** using keywords:

| Project | Keywords |
|---|---|
| NEOBPO | NEOBPO |
| Bichara Advogados | Bichara Advogados, Bichara |
| SL Cereais | SL Cereais |
| Persianas Canet | Persianas Canet, Canet |
| Omni Aviation | Omni Aviation |
| Cartão de Todos | Cartao de Todos, Cartão de Todos |
| Dotz S.A. | Dotz S.A., Dotz |
| Siderúrgica São Joaquim | Siderurgica Sao Joaquim, Siderurgica, Joaquim |
| ADEMICON | ADEMICON |
| EPR Participações | EPR Participacoes, EPR Participações |

### 3. Fallback — individual queries (if batch returns 0 or times out)

Run individual queries for high-risk projects only (go-live < 60 days). Max 5 individual queries.
If these were pre-launched in parallel (see Step 2), use their results immediately — do not re-fetch.
If all return 0: show warning `⚠️ ServiceNow retornou 0 casos — verifique a query ou reautentique.`

If ITSM completely inaccessible: set `source: "unavailable"`, store empty arrays, show `⚠️ ITSM indisponível` in footer.

### 4. Fetch WCR — reuse same Playwright session

Navigate using customer names from `portfolio.json` — **no user filter**:
```
https://itsm.services.sap/x_sapda_sap_wcr_re_sap_wcr_request_list.do?sysparm_query=state!=3^state!=4^(account.nameCONTAINS{CUSTOMER_1}^ORaccount.nameCONTAINS{CUSTOMER_2}^OR...)
```

Build the `account.nameCONTAINS` conditions dynamically from `portfolio.json` customers — same pattern as the cases query. Do **not** filter by `sys_created_by` or any user ID field.

**IMPORTANT — URL pattern**: Use the direct `.do?` URL (same reason as cases — no `now/nav` wrapper).
The list renders in the main document on direct URLs; no iframe access is needed.

Only show open/active states: `In Progress`, `Accepted for Planning`, `Open/New`.

### 5. Pseudonymize and save to data/itsm.json

**Before writing to disk**, pseudonymize all sensitive fields (customer names in case text, case subjects, WCR descriptions).

Merge the `PORTFOLIO_MAPPING` already obtained in csb-01-portal with any new tokens from the ITSM data:

```
POST https://anonymization-proxy.cfapps.eu12.hana.ondemand.com/pseudonymize
Body: { "text": "<all case rowText + WCR descriptions concatenated>" }
```

Retry up to **3 times** with exponential backoff (200ms, 600ms, 1200ms) if the proxy is unreachable.

- If proxy responds: replace real values in cases and WCR arrays with tokens. Merge returned `mapping` into `PORTFOLIO_MAPPING` → now called `SHARED_MAPPING`.
- If proxy fails after 3 retries: log `pseudonymize=unavailable`, write data without substitution, add footer note.

Write (pseudonymized) cases and WCR arrays to `$DATA_DIR/itsm.json`.

```bash
OUTPUT_DIR="${USERPROFILE:-$HOME}/Customer-Project-Status-Board"
printf '%s\n' "STEP:2:7:ServiceNow + WCR fetched" > "$OUTPUT_DIR/progress.tmp" && mv "$OUTPUT_DIR/progress.tmp" "$OUTPUT_DIR/progress.txt"
```
