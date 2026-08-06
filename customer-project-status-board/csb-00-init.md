# csb-00-init — Initialize Session

Sets up output directory, session ID, cache validation, and shared variables for the Customer-Project-Status-Board run.

## Steps

### 1. Resolve paths and create directories

```bash
OUTPUT_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board"
DATA_DIR="$OUTPUT_DIR/data"
mkdir -p "$DATA_DIR"
echo "OUTPUT_DIR=$OUTPUT_DIR"
echo "DATA_DIR=$DATA_DIR"
```

### 2. Declare session variables

```bash
OUTPUT_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board"
DATA_DIR="$OUTPUT_DIR/data"
USER_ID="${USERNAME:-$(whoami)}"
SESSION_ID="$(date +%Y%m%d_%H%M%S)"
TOTAL_STEPS=7
echo "SESSION_ID=$SESSION_ID"
echo "USER_ID=$USER_ID"
```

After setting `USER_ID`, resolve the user's **display name and email** by calling:
```
teams_web_my_profile
```
Extract:
- `displayName` → store as `USER_NAME` (e.g. the authenticated user's full name). Fall back to `USER_ID` if unavailable.
- `userPrincipalName` or `mail` → store as `USER_EMAIL` (e.g. `e.macedo@sap.com`). Fall back to `{USER_ID}@sap.com` if unavailable.

Use `USER_NAME` and `USER_ID` in the HTML shell bar and footer (already referenced as `{USER_NAME}` and `{USER_ID}` in csb-05-html).
Use `USER_EMAIL` in csb-04-crossref for "already actioned" email detection.

### 3. Write initial progress marker

```bash
OUTPUT_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board"
printf '%s\n' "STEP:0:7:Initializing..." > "$OUTPUT_DIR/progress.tmp" && mv "$OUTPUT_DIR/progress.tmp" "$OUTPUT_DIR/progress.txt"
```

### 4. Validate cache freshness

Check if `data/portfolio.json` exists, was written less than **4 hours** ago, **and contains valid data** (parseable JSON with a non-empty `projects[]` array).
If the run was invoked with the `fresh` argument (i.e. `FORCE_REFRESH=true`), skip cache and always fetch.

```bash
OUTPUT_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board"
DATA_DIR="$OUTPUT_DIR/data"
PORTFOLIO_CACHE="$DATA_DIR/portfolio.json"
CACHE_VALID=false
if [ "${FORCE_REFRESH:-false}" != "true" ] && [ -f "$PORTFOLIO_CACHE" ]; then
  AGE=$(( $(date +%s) - $(date -r "$PORTFOLIO_CACHE" +%s 2>/dev/null || echo 0) ))
  if [ "$AGE" -lt 14400 ]; then
    # Validate integrity: must be parseable JSON with at least one project
    # Use jq if available, fallback to grep-based check
    if command -v jq &>/dev/null; then
      PROJECT_COUNT=$(jq '.projects | length' "$PORTFOLIO_CACHE" 2>/dev/null || echo 0)
    else
      PROJECT_COUNT=$(grep -c '"id"' "$PORTFOLIO_CACHE" 2>/dev/null || echo 0)
    fi
    [ "$PROJECT_COUNT" -gt 0 ] && CACHE_VALID=true
  fi
fi
echo "CACHE_VALID=$CACHE_VALID"
```

If the file exists but is empty, unparseable, or has 0 projects: log `⚠️ Cache inválido — forçando rebusca` and set `CACHE_VALID=false`.

Signal `CACHE_VALID=true` to skip portal fetch in csb-01-portal if cache is fresh and valid.

**`fresh` argument**: if the user invoked the command with `fresh` as argument (e.g. `/Customer-Project-Status-Board fresh`), set `FORCE_REFRESH=true` before this step to bypass cache.

### 5. Validate write permissions

```bash
OUTPUT_DIR="C:/Users/${USERNAME}/OneDrive - SAP SE/Presentations/Customer-Project-Status-Board"
touch "$OUTPUT_DIR/.write_test" 2>/dev/null && rm "$OUTPUT_DIR/.write_test" || { echo "ERROR: No write permission on $OUTPUT_DIR"; exit 1; }
echo "Write permission OK"
```

### 6. Output session context to chat

Print a single line confirming initialization:
```
✅ Session initialized — ID: {SESSION_ID} · User: {USER_ID} · Cache: {valid (skip fetch) | stale (will fetch)}
```
