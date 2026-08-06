# csb-03-comms — Fetch Calendar and Emails

Fetches today's and tomorrow's calendar events and last 7 days of emails via Microsoft Graph API (no browser needed).
Both fetches run in parallel. Writes result to `data/comms.json`.

## Input

- `OUTPUT_DIR` / `DATA_DIR` from csb-00-init

## Output

`data/comms.json`:
```json
{
  "emails": [],
  "emails.sent": [],
  "events": [],
  "emailScope": "inbox | focused | all",
  "fetchedAt": "ISO timestamp"
}
```

## Steps

### 0. Ask user which email folder to search

Before fetching, always ask:

```
📧 Qual pasta de e-mail usar?

[1] Inbox — Focused + Other  (recomendado)
[2] Somente Focused
[3] Todas as pastas (Inbox, Sent, subpastas)
[4] Pasta específica (informar nome)
```

Store the choice as `EMAIL_SCOPE`. Default if no answer within 30 s: `[1] Inbox`.

If user chooses **[4]**, immediately ask:
```
Digite o nome da pasta (ou múltiplas separadas por vírgula):
Exemplos: Projetos SAP
          Projetos SAP, NEOBPO
```
Then resolve each folder name to its ID via Graph API before fetching:
```
GET /me/mailFolders?$filter=displayName eq '{FOLDER_NAME}'&$select=id,displayName
```
If a folder is not found, warn the user: `⚠️ Pasta "{name}" não encontrada — ignorada.`
Fetch messages from each found folder using `/me/mailFolders/{folderId}/messages` and merge results.

Map all choices to Graph API:
- `[1]` → `GET /me/mailFolders/inbox/messages` (sem filtro de classificação)
- `[2]` → `GET /me/mailFolders/inbox/messages` + `&$filter=... and inferenceClassification eq 'focused'`
- `[3]` → `GET /me/messages` (todas as pastas)
- `[4]` → `GET /me/mailFolders/{folderId}/messages` para cada pasta informada (merged)

Store the chosen scope label in `comms.json` as `"emailScope"` for display in the HTML footer.
For option [4], store as `"emailScope": "custom: Projetos SAP, NEOBPO"` (with folder names).

### 1. Fetch calendar and emails IN PARALLEL

Run both requests simultaneously — do not wait for one before starting the other.

**Calendar:**
```
teams_web_calendar: startDate=TODAY, endDate=TOMORROW_END
```
Fetch events for **today and tomorrow** in a single call (startDate = today 00:00 local, endDate = tomorrow 23:59 local).
Extract: date, time, title, key attendees for each event.
Tag each event with `"day": "today"` or `"day": "tomorrow"` in the output.

**Emails (last 7 days — unread only, using EMAIL_SCOPE from Step 0):**

Base URL from `EMAIL_SCOPE` selection above, then append:
```
  ?$filter=receivedDateTime ge {ISO_7D_AGO} and isRead eq false{FOCUSED_FILTER}
  &$orderby=receivedDateTime desc
  &$top=50
  &$select=subject,from,receivedDateTime,isRead,importance,bodyPreview,conversationId,flag,parentFolderId
```
Where `{FOCUSED_FILTER}` is ` and inferenceClassification eq 'focused'` only for scope [2], otherwise empty.
Replace `{ISO_7D_AGO}` with the ISO 8601 timestamp for exactly 7 days before now.

Fetch **only unread** messages (`isRead: false`). Include `flag` field to detect flagged and flag-completed items.
Focus on unread messages as primary signal for TODO prioritization; also flag important/flagged ones.

**Replies sent by the user (last 7 days — for "already actioned" detection):**

In addition to the unread inbox query above, also fetch emails **sent by the user** within the same 7-day window. This is needed so csb-04-crossref can detect if the user already replied to a thread:
```
GET /me/mailFolders/sentitems/messages
  ?$filter=sentDateTime ge {ISO_7D_AGO}
  &$select=subject,from,sentDateTime,conversationId
  &$top=50
  &$orderby=sentDateTime desc
```
Store these in a separate `emails.sent[]` array in `comms.json`. They are **not** shown in the UI — used only for "already actioned" detection in csb-04-crossref.

### 2. Handle failures gracefully

- Calendar unavailable → store `events: []`, note in HTML: `"Calendar data unavailable"`
- Emails unavailable → store `emails: []`, note in HTML: `"Email data unavailable"`
- Partial failure is acceptable — continue with available data

### 3. Save to data/comms.json

Write emails and events arrays to `$DATA_DIR/comms.json`.

```bash
OUTPUT_DIR="${USERPROFILE:-$HOME}/Customer-Project-Status-Board"
printf '%s\n' "STEP:3:7:Calendar + emails fetched" > "$OUTPUT_DIR/progress.tmp" && mv "$OUTPUT_DIR/progress.tmp" "$OUTPUT_DIR/progress.txt"
```
