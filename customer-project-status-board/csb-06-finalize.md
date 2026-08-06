# csb-06-finalize — Log, Notify, and Open Browser

Writes the execution log, sends a Teams summary notification, cleans up old files, and opens the HTML report.

## Input

- `SESSION_ID`, `USER_ID`, `NNN`, `YYYYMMDD` from session
- `data/portfolio.json`, `data/itsm.json`, `data/comms.json` for metrics
- `OUTPUT_DIR` = `C:\Users\%USERNAME%\OneDrive - SAP SE\Presentations\Customer-Project-Status-Board`
- `DATA_DIR` = `OUTPUT_DIR\data`
- HTML filename pattern: `CSB_{YYYYMMDD}_{NNN}.html`

## Steps

### 1. Write execution log

```bash
DATA_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board/data"
printf '%s\n' "STEP:6:7:Writing log" > "$DATA_DIR/progress.txt"
```

Append one summary line to `execution_log.txt`:
```
{YYYY-MM-DD} {HH:MM} BRT | seq={NNN} | source={portal|cache|last_known|baseline} | cases={N} | emails={N} | events={N} | file=CSB_{YYYYMMDD}_{NNN}.html
```

```bash
printf '%s\n' "{LOG_LINE}" >> "$DATA_DIR/execution_log.txt"
```

### 2. Send Teams summary notification

Using `teams_web_send`, send a self-message (to your own chat).

**Cache the chat ID** to avoid repeated lookup: after the first successful send, store the conversation ID in `data/.teams_chat_cache`. On subsequent runs, read it directly and skip the `teams_web_find_private_chat` call. If the cache is missing or send fails with "not found", fall back to `teams_web_find_private_chat` and update the cache.

```
📊 Customer Project Status Board — {DATE} {TIME} BRT

{N} projects · {N} cases ({N} P1, {N} P2) · {N} alerts
{CRITICAL_ITEMS — one line each, max 3}

📁 {HTML_FILENAME}
```

If Teams send fails: log warning, continue — do not abort.

### 3. Verify HTML file and open in browser

**Before opening**, verify that the file was actually written:

```bash
HTML_FILE="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board/CSB_{YYYYMMDD}_{NNN}.html"
FILE_SIZE=$(wc -c < "$HTML_FILE" 2>/dev/null || echo 0)
if [ "$FILE_SIZE" -lt 10240 ]; then
  echo "ERROR: HTML file missing or too small (${FILE_SIZE} bytes) — report was not generated."
  exit 1
fi
```

If the file is missing or smaller than 10KB: abort with a clear error message. Do **not** proceed to open the browser.

If the file is valid, open it using PowerShell `Invoke-Item` (required on Windows — `cmd /c start` fails silently in the Claude Code Bash environment):

```bash
powershell.exe -Command "Invoke-Item 'C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board/CSB_{YYYYMMDD}_{NNN}.html'"
```

Use `dangerouslyDisableSandbox: true` for this Bash call.

### 4. Mark complete and cleanup

```bash
printf '%s\n' "STEP:7:7:DONE" > "C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board/data/progress.txt"
```

Confirm to user:
```
✅ Done — File saved: {FULL_PATH}
```

**Cleanup old HTML files (background — do not block):** After confirming to the user, delete HTML files older than 30 days asynchronously:

```bash
find "C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board" -name "CSB_*.html" -mtime +30 -delete 2>/dev/null &
```
