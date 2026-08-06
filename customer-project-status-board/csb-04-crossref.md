# csb-04-crossref — Pseudonymize and Cross-Reference

Pseudonymizes all collected data (SAP Data Privacy Policy), then cross-references portfolio, cases, and comms
to produce alerts, TODO list, and meeting prep. Writes result to `data/crossref.json`.

## Input

- `data/portfolio.json` from csb-01-portal
- `data/itsm.json` from csb-02-itsm
- `data/comms.json` from csb-03-comms

## Output

`data/crossref.json`:
```json
{
  "alerts": [],
  "todos": [],
  "nextActions": [],
  "meetingPrep": [],
  "goLiveChanges": [],
  "generatedAt": "ISO timestamp"
}
```

## Steps

### 1. Validate inputs

Check that all three input files exist in `data/`. If any is missing:
- Log warning in the HTML footer
- Continue with available data — do NOT abort

### 2. Load pseudonymization mapping

The data in the three input files has already been pseudonymized by csb-01-portal and csb-02-itsm before being written to disk. Load the consolidated mapping:

```
Read data/mapping.json → store as SHARED_MAPPING
```

If `data/mapping.json` is missing or empty, log `mapping=unavailable` and proceed — de-pseudonymization in csb-05-html will use the raw tokens as-is, and a footer warning will be shown.

**All LLM analysis below uses the already-pseudonymized content from the input files.**

### 3. Cross-reference: project × calendar × email

For each project in portfolio, check:
- Is there a calendar event today mentioning this project/customer/partner? → mark as `hasMeetingToday: true`
- Is there a recent unread email about this project? → attach email subject + sender
- Does an email request action before a meeting today?
- Is there a meeting without a status email (prep needed)?

### 4. Detect go-live date changes

Compare current go-live dates in `portfolio.json` against `last_known_portfolio.json`.
For each project where the date changed, add to `goLiveChanges[]`:
```json
{ "project": "SL Cereais", "previousDate": "2026-06-01", "currentDate": "2026-07-01", "detectedAt": "..." }
```

### 5–7. Compute alerts, next actions, and prioritized TODO (single batched LLM call)

**Performance**: Steps 5, 6, and 7 are batched into one LLM prompt to avoid multiple sequential inference calls. Meeting Prep (Step 8) is NOT included here — it requires per-event detail and runs separately.

Build the following prompt and submit as a single analysis call:

```
You are analyzing a cloud project portfolio. For each project, compute:

A) ALERTS — flag all that apply:
   - 🔴 Red status (status = Red)
   - 🎫 P1/P2 case (cases with priority P1 or P2)
   - ⚠️ Go-live < 30 days (weeksOut ≤ 4)
   - ⚪ Partner Not Started (partnerStatus = Not Started AND go-live < 16 weeks)
   - ⏸ On Hold (stage = On Hold)
   - 🕐 Not Started (stage = Not Started)
   - 📅 Meeting today (hasMeetingToday = true AND has any other alert)
   - 📆 Go-live changed (appears in goLiveChanges[])

B) NEXT ACTION — one sentence per flagged project, priority order:
   Red/escalation → P1 case → go-live < 30d → partner issues → on hold/not started

C) PRIORITIZED TODO — merge project alerts + unread emails + calendar prep:
   - 🔴 Critical: alert AND meeting TODAY
   - 🟡 Important: unread email referencing flagged project
   - 🟢 Normal: routine check-ins
   - 📅 Prep: specific prep for today's meetings

   Email "already actioned" filter — BEFORE assigning priority, skip an email if ANY:
   1. emails.sent[] has same conversationId AND sentDateTime > original receivedDateTime
   2. bodyPreview/subject contains "Re:", "Accepted:", "Fwd:" with user as sender
   3. flagStatus = "complete" or "flagComplete"
   Already actioned → exclude entirely (if fully done) OR downgrade to ✅ Respondido (informativo)

Input data:
- projects (pseudonymized): {PROJECTS_JSON}
- cases (pseudonymized): {CASES_JSON}
- emails (unread, pseudonymized): {EMAILS_JSON}
- emails.sent (last 7 days, pseudonymized): {SENT_JSON}
- calendar events today/tomorrow (pseudonymized): {EVENTS_JSON}
- goLiveChanges: {GOLIVE_CHANGES_JSON}
- crossref results (hasMeetingToday per project): {CROSSREF_JSON}

Return JSON with keys: alerts[], nextActions[], todos[]
```

Apply the "already actioned" filter using the rules above before any email is promoted to TODO.

### 8. Generate Meeting Prep cards

For each calendar event today matching a project/customer/partner, generate:
- Project status snapshot
- 3 talking points derived from alerts (most urgent first)
- If no alerts: generic check-in points

### 9. Save to data/crossref.json

Write all computed data. Also save `SHARED_MAPPING` to `data/mapping.json` for use by csb-05-html (merges tokens from portfolio, itsm, and comms steps).

```bash
OUTPUT_DIR="${USERPROFILE:-$HOME}/Customer-Project-Status-Board"
printf '%s\n' "STEP:4:7:Cross-reference complete" > "$OUTPUT_DIR/progress.tmp" && mv "$OUTPUT_DIR/progress.tmp" "$OUTPUT_DIR/progress.txt"
```
