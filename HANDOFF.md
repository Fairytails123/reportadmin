# Dog Report V7 — Marker-Based Automation System

> **HANDOFF DOCUMENT** — This plan is a self-contained handoff to continue the project on a different computer. All credentials, IDs, URLs, and current state are captured below.

## Context

The current Dog Report V6 n8n workflow creates one JotForm submission per photo with only 2 fields filled (image URL + dog name). Staff must manually fill 40+ fields per submission. The goal is to build a **marker-based system** where staff select behaviour markers (1-5) via Telegram, upload photos grouped by marker, and receive **prefill URLs** with all behaviour fields auto-populated. A separate **admin panel website** lets admins configure what each marker auto-fills on JotForm.

**Status (as of 2026-04-26):** Components 1, 2, and 4 are complete and live. Component 3 (Telegram Marker Bot) is imported into n8n but not yet published or tested end-to-end. The next person picking this up should focus on Phase 3 + Phase 5 (publish bot + integration test).

---

## 0. Credentials, IDs, and URLs (Source of Truth)

**⚠️ Sensitive — keep this document private.**

### n8n Cloud
- Instance URL: `https://ftmanager.app.n8n.cloud`
- Project ID: `NiLRp6ylcs2c96tq`
- Project workflows: `https://ftmanager.app.n8n.cloud/projects/NiLRp6ylcs2c96tq/workflows`
- Account: Logged in as `Fairytails123` on the host machine

### n8n Workflow IDs (V7)
| Name | ID | URL |
|------|-----|-----|
| Dog Report V7 - Setup | `jzdMCWVjNLA7AE71` | `https://ftmanager.app.n8n.cloud/workflow/jzdMCWVjNLA7AE71` |
| Dog Report V7 - Admin API | `kP0HENv1MCxehoaz` | `https://ftmanager.app.n8n.cloud/workflow/kP0HENv1MCxehoaz` |
| Dog Report V7 - Telegram Marker Bot | `ufyIpu25DlYdcaFb` | `https://ftmanager.app.n8n.cloud/workflow/ufyIpu25DlYdcaFb` |

### n8n Credentials (referenced inside workflow JSON)
- Telegram credential ID: `P2xKE6xArSQLZGu6` (name: "telegram dog photo")
- Google Sheets OAuth credential ID: `DZAqFzkfKzaYA81D` (name: "Google Sheets account")

### Google Sheets
- Spreadsheet ID: `17O_y46ESKMOXo_l1zln_Mmd34VsdE7dXzFS8-u-cllg`
- URL: `https://docs.google.com/spreadsheets/d/17O_y46ESKMOXo_l1zln_Mmd34VsdE7dXzFS8-u-cllg/edit`
- V6 sheets (existing, untouched): `Active_Queue` (gid=0), `Batch_State` (gid=1328868604), `Global_Ledger` (gid=777962888)
- V7 sheets (new, populated): `Markers_Config`, `Sessions`, `Session_Photos`

### JotForm
- Form ID: `253635667896376`
- Form name: "Dog School Report v2.3"
- Form URL: `https://form.jotform.com/253635667896376`
- API endpoint: `https://eu-api.jotform.com` (EU instance)
- API key: `5c49c157c95e409789eeec38ff6d6428`

### Telegram Bot
- Bot token: `8477847671:AAHmrHbFyOwgAdy70t06FrCy_qZRTIKswp8`
- Webhook ID (from V6): `dog-report-webhook-v6` (V7 uses its own trigger)

### ImgBB (image hosting)
- API key: `3a4df3f8d304243cd6de77671232e8f8`
- Upload endpoint: `https://api.imgbb.com/1/upload`

### Admin Panel
- GitHub repo: `https://github.com/Fairytails123/reportadmin` (owner: Fairytails123)
- GitHub Pages live URL: `https://fairytails123.github.io/reportadmin/`
- Cache buster: append `?t=<timestamp>` if you see a stale version
- Tech: single self-contained `index.html` (no build step)

### n8n Webhook Endpoints (Admin API — published & live)
- `GET  https://ftmanager.app.n8n.cloud/webhook/v7-markers` — returns `{"markers":[...]}`
- `POST https://ftmanager.app.n8n.cloud/webhook/v7-markers-update` — accepts `{marker_number, marker_name, marker_description, mappings}`
- `GET  https://ftmanager.app.n8n.cloud/webhook/v7-jotform-fields` — returns `{"fields":[...]}`

All Admin API endpoints have `Access-Control-Allow-Origin: *` for the static admin panel to call them.

---

## System Architecture (3 Components)

```
[Telegram Bot] <-> [n8n Workflows] <-> [Google Sheets]
                        ^                      ^
                        |                      |
               [Admin Panel Website] ----------+
               (Vanilla HTML on GitHub Pages)
```

### Component 1: Admin Panel — single self-contained `index.html` on GitHub Pages (Tailwind CDN + vanilla JS — no build step)
### Component 2: Admin API — n8n workflow with 3 webhook endpoints
### Component 3: Telegram Marker Bot — n8n workflow with 7-branch router

> **Design note:** The original plan called for Next.js with static export, but during implementation it was simplified to a single HTML file since GitHub Pages serves static content best, and there is no need for a build step. The single-file approach is easier to deploy and edit. Tailwind is loaded via CDN.

---

## 1. Google Sheets — New Sheets (in existing spreadsheet `17O_y46ESKMOXo_l1zln_Mmd34VsdE7dXzFS8-u-cllg`)

### Sheet: `Markers_Config`
| Column | Type | Example |
|--------|------|---------|
| Marker_Number | 1-5 | `1` |
| Marker_Name | string | `Calm & Well-Behaved` |
| Marker_Description | string | `Dog was relaxed, happy, no incidents` |
| Field_ID | string | `6` |
| Field_Name | string | `myMood` (JotForm field name for URL prefill) |
| Field_Label | string | `My mood was` |
| Field_Type | checkbox/radio/dropdown/rating/number/text | `checkbox` |
| Field_Value | string | `Relaxed` |
| Updated_At | ISO datetime | `2026-04-07T10:00:00Z` |

> One row per field-value. Marker 1 with mood=Happy+Relaxed = 2 rows (both Field_ID=6).

### Sheet: `Sessions`
| Column | Type | Example |
|--------|------|---------|
| Session_ID | string | `SESS_1712505600000` |
| Staff_Chat_ID | string | `123456789` |
| Status | string | `OPEN` / `COLLECTING` / `FINISHED` |
| Active_Marker | number | `0` (none) or `1-5` |
| Markers_Done | string | `1,3` (comma-separated completed markers) |
| Created_At | ISO datetime | |
| Finished_At | ISO datetime | |

### Sheet: `Session_Photos`
| Column | Type | Example |
|--------|------|---------|
| Session_ID | string | FK to Sessions |
| Marker_Number | number | `2` |
| File_Unique_ID | string | Telegram dedup ID |
| ImgBB_URL | string | Permanent hosted URL |
| ImgBB_Delete_URL | string | Cleanup URL |
| Dog_Name | string | From caption (title-cased) |
| Uploaded_At | ISO datetime | |

---

## 2. JotForm Field Name Map (for prefill URLs)

Prefill URL format: `https://form.jotform.com/253635667896376?fieldName=value&fieldName2=value2`
- Checkboxes (multi-value): `myMood=Happy,Relaxed`
- Radio/Dropdown: `myBarking=Low`
- Rating: `mysit=5`
- Number: `meJumping=0`
- Date: `date[month]=04&date[day]=07&date[year]=2026`
- Text: `imgurl=https://i.ibb.co/abc.jpg`

**Complete field name map (from live form data):**

| Field ID | Field Name | Label | Type |
|----------|------------|-------|------|
| 6 | myMood | My mood was | checkbox |
| 8 | mySocial | My social skills | checkbox |
| 14 | vomiting | Vomiting | checkbox |
| 15 | diarrhoea | Diarrhoea | checkbox |
| 33 | mysit | My "Sit" cue | rating (1-5) |
| 34 | mystaywait | My "Stay/Wait" cue | rating (1-5) |
| 35 | meJumping | Me jumping up | number |
| 36 | instancesOf36 | Me being impatient | number |
| 37 | myInteraction | Interaction with staff | radio |
| 38 | todayMy | Play with other dogs | dropdown |
| 40 | myBarking | My barking was | radio |
| 42 | iRestedslept | I Rested/Slept | radio |
| 51 | date | Date | datetime |
| 56 | initials | Initials | dropdown |
| 69 | myName69 | My Name | dropdown |
| 75 | typeA75 | Overall Behaviour | widget |
| 87 | imgurl | Image URL | textbox |
| 114 | upsetTummy114 | Upset Tummy | checkbox |
| 115 | enrichmentActivities | Enrichment activities | radio |
| 119 | memberOf | Training programme | radio |
| 121 | myCalmdown | Calm-down break duration | dropdown |
| 125 | myAfter125 | Journey home | radio |
| 126 | iWill | Coming home in | dropdown |
| 127 | myStop | My stop number | dropdown |
| 128 | myCarer128 | Getting a little too... | checkbox |
| 131 | myEnergy131 | My energy level | checkbox |
| 132 | iHad132 | Behavioural guidance | dropdown |
| 133 | iHad | Calm-down breaks | checkbox |
| 140 | myToilet | Toilet habits | radio |
| 141 | myWater | Water intake | radio |
| 142 | highlightOf | Highlight of my day | textbox |
| 143 | myPlay | Play buddies | textbox |

---

## 3. n8n Workflow A: Telegram Marker Bot

**Trigger:** Telegram Trigger (message updates)

**Router Switch** — 7 branches:

### Branch 1: `/start`
1. Read Sessions → filter Staff_Chat_ID + Status != FINISHED
2. IF session exists → "Session already open. Pick marker 1-5"
3. ELSE → Read Markers_Config (distinct marker names) → Create session row (OPEN, Active_Marker=0) → Send welcome with marker list

### Branch 2: Digit `1-5` (marker selection)
1. Read Sessions → find OPEN/COLLECTING session
2. IF no session → "Use /start first"
3. ELSE → Update session (Active_Marker=N, Status=COLLECTING) → Read Markers_Config for marker N → Send "Marker N: {name}. Send photos now. /Nfinish when done."

### Branch 3: Photo received
1. Extract: file_id, file_unique_id, chat_id, caption → dogName (title-cased)
2. Read Sessions → find COLLECTING session with Active_Marker > 0
3. IF no session/marker → "Select a marker first (1-5)"
4. Check Global_Ledger for dedup
5. IF duplicate → "Duplicate ignored"
6. ELSE →
   - HTTP: Telegram getFile → Build file URL
   - HTTP: Upload to imgBB (key: `3a4df3...`)
   - Append to Session_Photos (Session_ID, Marker_Number, File_Unique_ID, ImgBB_URL, Dog_Name)
   - Append to Global_Ledger
   - Send "Photo saved for Marker N ({dogName}). Send more or /Nfinish"

### Branch 4: `/Nfinish` (regex `/[1-5]finish`)
1. Parse N from command
2. Read Sessions → find session with Active_Marker = N
3. IF no match → "No active marker N"
4. ELSE →
   - Count photos for this marker in Session_Photos
   - Update session: append N to Markers_Done, set Active_Marker=0, Status=OPEN
   - Send "Marker N closed ({count} photos). Pick next marker or /allfinished"

### Branch 5: `/allfinished`
1. Read Sessions → find OPEN/COLLECTING session
2. Read ALL Session_Photos for this session
3. Read Markers_Config for ALL markers in Markers_Done
4. **Code node (JavaScript):** Build prefill URLs
   - Group photos by Dog_Name
   - For each dog:
     - Merge all marker configs: checkboxes UNION values, radio/dropdown = last marker wins
     - Build URL: `https://form.jotform.com/253635667896376?` + encoded params
     - Include: `myName69={dogName}`, `imgurl={first_photo_url}`, `date[month/day/year]=today`
   - Return array of {dogName, url, photoCount, markers}
5. Format message with numbered list of prefill links
6. Update session: Status=FINISHED, Finished_At=now
7. Send links to staff

### Branch 6: `/status`
1. Read session → Show active marker, markers done, photo count per marker

### Branch 7: `/cancel`
1. Find session → Update to FINISHED → "Session cancelled"

---

## 4. n8n Workflow B: Admin API (3 webhook endpoints)

### `GET /webhook/markers`
1. Webhook Trigger → Read Markers_Config (all rows) → Code: group by Marker_Number → Respond with JSON + CORS headers

### `POST /webhook/markers`
1. Webhook Trigger → Validate body → Read all Markers_Config → Filter out target marker rows → Add new rows → Clear sheet → Rewrite all → Respond success

### `GET /webhook/jotform-fields`
1. Webhook Trigger → HTTP: GET `https://eu-api.jotform.com/form/253635667896376/questions?apiKey=...` → Code: transform to clean field list → Respond with JSON

All endpoints include CORS headers (`Access-Control-Allow-Origin: *`).

---

## 5. Admin Panel — Single HTML file on GitHub Pages

### Tech: Vanilla HTML + Tailwind CSS via CDN + vanilla JS (no build step, no framework)

### Single-page sections (toggled via JS, no routing):
- **Dashboard view** — 5 marker cards showing name + description + mapping count
- **Marker editor view (Markers 1-5)** — edit name, description, add/remove field mappings
  - Field selector dropdown (populated from `GET /v7-jotform-fields`)
  - Value selector renders dynamically per field type:
    - `control_checkbox` → individual checkboxes for each JotForm option
    - `control_radio` / `control_dropdown` → `<select>` with each JotForm option
    - `control_rating` → number input 1-5
    - `control_spinner` → number input
    - `control_textbox` / `control_textarea` → text input
  - Save button → `POST /v7-markers-update`
- **Field Reference view** — read-only sortable/filterable table of all JotForm fields + options

### Key implementation details (gotchas):
1. The admin panel must **strip the `control_` prefix** from JotForm field types before comparing (e.g. `control_checkbox` → `checkbox`).
2. The `GET /v7-jotform-fields` endpoint returns `{fields:[...]}`. Must unwrap with `data.fields || data` to handle both shapes.
3. The `GET /v7-markers` endpoint returns markers with keys `number`, `name`, `description` — but `POST /v7-markers-update` expects `marker_number`, `marker_name`, `marker_description`. Normalize both.
4. Field IDs are returned as numbers in marker mappings but as strings in the JotForm fields list. Compare with `String(a) === String(b)`.

### Deployment: `git push` to `main` → GitHub Pages auto-deploys in ~30s

---

## 6. Default Marker Presets (initial Markers_Config data)

| # | Name | Key auto-fills |
|---|------|---------------|
| 1 | Calm & Well-Behaved | mood=Relaxed+Happy, social=Calm, barking=None, energy=Low, guidance=Not required |
| 2 | Playful & Energetic | mood=Playful+Happy, social=Nice Play, barking=Low, energy=Medium |
| 3 | Needs Guidance | mood=Hyperactive, barking=Medium, energy=High, guidance=Once |
| 4 | Challenging Day | mood=Anxious, social=Growling, barking=High, guidance=Twice |
| 5 | Aggressive / Unsafe | mood=Scared, social=Instigating Fights, barking=Excessive, guidance=Multiple |

> These are fully editable via the admin panel.

---

## 7. Implementation Status & Remaining Work

### ✅ Phase 1: Google Sheets setup — COMPLETE
- 3 new sheets created: Markers_Config, Sessions, Session_Photos
- 5 default marker presets populated (37 rows total)
- Fix applied: `alwaysOutputData: true` on Read Existing Markers node

### ✅ Phase 2: Admin API workflow (n8n) — COMPLETE & PUBLISHED
- Workflow ID: `kP0HENv1MCxehoaz`
- 3 webhook endpoints: GET `/v7-markers`, POST `/v7-markers-update`, GET `/v7-jotform-fields`
- File: `workflows/v7-admin-api.json`

### ⬜ Phase 3: Telegram Bot workflow (n8n) — IMPORTED, NOT YET PUBLISHED
- 53-node workflow with 7-branch router
- File: `workflows/v7-telegram-bot.json`
- **TODO:** Publish the workflow in n8n, then test each command
- **TODO:** May need same `alwaysOutputData` fixes on Google Sheets read nodes

### ✅ Phase 4: Admin Panel website — COMPLETE & LIVE
- Repo: https://github.com/Fairytails123/reportadmin
- Live: https://fairytails123.github.io/reportadmin/
- Single HTML file, Tailwind CSS, vanilla JS
- Dashboard shows 5 markers, editor mirrors exact JotForm options, save works
- Bugs fixed: API response normalization, JotForm fields `{fields:[...]}` unwrapping, `control_` type prefix stripping

### ⬜ Phase 5: Integration testing — REMAINING
- **TODO:** Publish Telegram Bot workflow
- **TODO:** Send `/start` via Telegram → test full flow
- **TODO:** Verify prefill URLs open JotForm with correct values
- **TODO:** Test concurrent sessions from different staff

---

## 8. Verification Plan

1. ✅ **Sheets:** 3 new sheets verified with correct headers and data
2. ✅ **Admin API:** GET returns 5 markers; POST saves successfully (200 + `{"success":true}`)
3. ✅ **Admin Panel:** Dashboard loads markers, editor shows JotForm options, save persists
4. ⬜ **Telegram flow:** Send `/start` → get marker list → send `1` → get prompt → send photo → get confirmation → `/1finish` → close marker → `/allfinished` → receive prefill URL
5. ⬜ **Prefill URL:** Open the generated URL in browser → verify checkboxes are ticked, dropdowns selected, image URL populated, date filled, dog name set
6. ⬜ **Admin→Bot integration:** Edit marker in admin panel → verify Markers_Config sheet updated → re-run Telegram flow → verify new prefill values reflect changes

---

## 9. Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| Prefill URL > 2000 chars | Test with all 5 markers; if too long, use JotForm API submission + edit link instead |
| Widget field `typeA75` may not prefill via URL | Test early; fallback to API submission for this field |
| Google Sheets rate limits on rapid photo uploads | Add 500ms Wait node between sheets operations |
| Abandoned sessions | /cancel command exists; consider auto-close after 24h via scheduled workflow |
| Commas in checkbox values break prefill | URL-encode values; test with special characters |
| Google Sheets read returns empty → breaks flow | **FIXED:** `alwaysOutputData: true` on Admin API; **TODO:** verify same on Telegram Bot workflow |
| GitHub Pages cache serves stale HTML | Use `?t=timestamp` cache buster; max-age=600s CDN cache |

---

## 10. Key Files

| File | Purpose |
|------|---------|
| `workflows/v7-setup.json` | One-time setup: creates 3 sheets + populates defaults |
| `workflows/v7-admin-api.json` | Admin API: 3 webhook endpoints (14 nodes) |
| `workflows/v7-telegram-bot.json` | Telegram bot: 7-branch router (53 nodes) |
| `admin-panel/index.html` | Admin panel: single HTML file with Tailwind + vanilla JS |
| Spreadsheet `17O_y46ESKMOXo_l1zln_Mmd34VsdE7dXzFS8-u-cllg` | Google Sheets data store |
| JotForm `253635667896376` | Target form (Dog School Report v2.3) |

## 11. Next Immediate Actions

1. **Publish the Telegram Bot workflow** in n8n (it's imported but inactive)
2. **Add `alwaysOutputData: true`** to ALL Google Sheets "read" nodes in the Telegram Bot workflow (same bug as Admin API)
3. **Test `/start` command** via Telegram to verify the bot responds
4. **Test full flow**: /start → pick marker → upload photo → /1finish → /allfinished → verify prefill URL
5. **Test prefill URL** in browser to confirm JotForm fields are correctly pre-populated

---

## 12. Handoff Instructions (Continuing on Another Machine)

### 12.1 What you need on the new machine

Required tooling:
- `git` and `gh` (GitHub CLI) — authenticated as user `Fairytails123` (`gh auth login`)
- `curl` — for testing webhook endpoints
- `node` — for running quick JS one-liners against API responses
- A modern browser to access the admin panel and n8n editor
- Access to the n8n cloud instance at `https://ftmanager.app.n8n.cloud` (the user is already logged in there)

Optional but useful:
- Claude in Chrome (browser automation) — used heavily during development to drive the n8n UI
- `mcp__bae8f823-…` n8n MCP server — used to read workflow metadata; note it returns "Workflow is not available in MCP. Enable MCP access in workflow settings." for V7 workflows because MCP access isn't toggled on. Not blocking.

### 12.2 Cloning the project

The "project" is split across three locations. There is **no single repo** that contains all three components — handle each separately.

1. **Workflows + admin-panel source files** (Windows local path on host machine):
   ```
   C:\Users\Kam\OneDrive\Business\CODING\Telegram_jotform_n8nphotoreport\
   ├── Dog Report System V6 (v36 - URL with Token).json   # original V6 reference
   ├── workflows\
   │   ├── v7-setup.json
   │   ├── v7-admin-api.json
   │   └── v7-telegram-bot.json
   └── admin-panel\
       └── index.html
   ```
   On the new machine, sync the OneDrive folder OR copy these 4 files manually.

2. **Admin panel deployed repo**:
   ```
   git clone https://github.com/Fairytails123/reportadmin
   ```
   The deployed `index.html` is also at `admin-panel/index.html` in the OneDrive folder — they are kept in sync by manually copying.

3. **n8n workflows are stored in n8n Cloud**, not on disk. The local JSON files are the canonical source — n8n imports them. If you need to re-export, use n8n's "Download" menu on each workflow.

### 12.3 Memory files on host machine (Windows paths)

The host has Claude project memory at:
```
C:\Users\Kam\.claude\projects\C--Users-Kam-OneDrive-Business-CODING-Telegram-jotform-n8nphotoreport\memory\
├── MEMORY.md                       # index
├── project_dog_report_v7.md        # design doc (this plan, condensed)
├── reference_apis_and_ids.md       # all credentials + JotForm field map
└── reference_admin_panel.md        # admin panel deployment info
```

If transferring to a Mac/Linux machine, the equivalent path is `~/.claude/projects/<encoded-project-path>/memory/`. Recreate these files on the new machine with the same content (most of which is reproduced in §0 and §2 of this document).

### 12.4 Step-by-step: how to publish & test the Telegram bot (the remaining work)

This is the critical remaining task. Estimated time: 30-60 minutes.

**Step A — Open the Telegram bot workflow:**
1. Navigate to `https://ftmanager.app.n8n.cloud/workflow/ufyIpu25DlYdcaFb`
2. Confirm you see "Dog Report V7 - Telegram Marker Bot" with 53 nodes laid out in 7 horizontal branches

**Step B — Apply the `alwaysOutputData` fix to every Google Sheets "read" node:**

The Admin API workflow had a bug where Google Sheets "Get Row(s)" nodes returned no items when the sheet was empty, halting the downstream flow. The fix is to enable `Always Output Data` in each read node's Settings tab. The same fix is likely needed in the Telegram bot.

Apply to these read nodes (visible in `workflows/v7-telegram-bot.json`):
- `Read Sessions For Start`
- `Read Sessions For Marker`
- `Read Sessions For Photo`
- `Read Sessions For Finish`
- `Read Sessions AllFinish`
- `Read Sessions For Status`
- `Read Sessions For Cancel`
- `Read Marker Config` (used in /start to build welcome message)
- `Read Marker Config Detail` (used after marker selection)
- `Check Duplicate Ledger`
- `Read Session Photos` (in /allfinished and /status branches)
- `Read All Markers Config` (in /allfinished)

For each node:
1. Double-click the node to open it
2. Click the **Settings** tab
3. Toggle **Always Output Data** to ON (green)
4. Close the panel
5. Save (Ctrl+S) — n8n will prompt for a version name; just click Save

After all nodes are updated, click the orange **Publish** button in the top-right and confirm in the dialog.

**Step C — Test each branch via Telegram:**

Open Telegram, find the bot (whatever its handle is — it uses token `8477847671:…`), and run this exact sequence:

1. `/start`
   - Expected: "Welcome! Pick behaviour marker 1, 2, 3, 4, or 5: …" listing all 5 markers from `Markers_Config`
   - If you instead get nothing, check the n8n Executions tab for errors

2. Send `2` (just the digit)
   - Expected: "Marker 2: Playful & Energetic. Send photos now. Use /2finish when done."

3. Send a photo with caption `Bella`
   - Expected: "✅ Bella saved for Marker 2. Send more or /2finish"
   - Verify the photo URL appears in the `Session_Photos` sheet

4. `/2finish`
   - Expected: "Marker 2 closed (1 photo). Pick another marker (1-5) or /allfinished"

5. `/allfinished`
   - Expected: A message with a JotForm prefill URL. Open it in a browser.
   - Verify: dog name `Bella` is in field 69, image URL is in field 87, the checkboxes/dropdowns from Marker 2 (mood=Playful+Happy, social=Nice Play, etc.) are pre-filled

**Step D — Test admin → bot integration:**
1. Open `https://fairytails123.github.io/reportadmin/?t=<timestamp>` (cache buster)
2. Click Marker 2
3. Add a new mapping: field "Highlight of my day" → text value "Test highlight"
4. Click "Save Changes"
5. Verify in Google Sheets that the new row appears in `Markers_Config`
6. Re-run the Telegram flow (Step C above) and confirm the new prefill URL includes `highlightOf=Test%20highlight`

### 12.5 Known issues to be aware of

1. **Marker 1 has corrupt name `1` (a number, not a string)** — someone manually edited it in Google Sheets at one point. Fix by editing Marker 1 in the admin panel, setting name to e.g. "Calm & Well-Behaved", and saving.
2. **GitHub Pages cache** — the live site can serve a stale `index.html` for up to 10 minutes (`max-age=600`). Always test with `?t=<timestamp>` query string to bypass.
3. **JotForm widget field 75 (`typeA75`, "Overall Behaviour")** — untested whether prefill via URL works for JotForm widget fields. May need to fall back to an API submission for this field if URL prefill fails. Test early.
4. **URL length** — Maximum prefill URL with all 5 markers active estimated at ~1500 chars. Browsers handle up to ~2000 reliably. If exceeded, switch to JotForm API submission + return the edit link instead of a prefill URL.
5. **MCP access on V7 workflows is OFF** — `get_workflow_details` via the n8n MCP returns "Workflow is not available in MCP". Enable in each workflow's Settings → MCP if you want programmatic read access.

### 12.6 How to roll back / recreate from scratch

If something breaks badly:
1. **Sheets data:** All 3 V7 sheets can be safely cleared and re-seeded. Run the `v7-setup.json` workflow's Manual Trigger once (it's idempotent — uses upsert/append). Then POST the 5 default markers via curl to `/v7-markers-update` (see commands logged in the prior chat history).
2. **Workflows:** Delete from n8n, re-import from `workflows/*.json`, re-publish.
3. **Admin panel:** `git clone https://github.com/Fairytails123/reportadmin`, copy `admin-panel/index.html` over `index.html`, commit, push. GitHub Pages auto-deploys in ~30 seconds.

The V6 workflow (`Dog Report System V6 (v36 - URL with Token).json`) is untouched and still functional — V7 runs alongside it.

### 12.7 Quick verification commands

Run these on the new machine to confirm the system is alive:

```bash
# Confirm Admin API is up and returns 5 markers
curl -s https://ftmanager.app.n8n.cloud/webhook/v7-markers | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);console.log('Markers:', r.markers.length); r.markers.forEach(m=>console.log(' '+m.number+': '+m.name+' ('+m.mappings.length+' mappings)'))})"

# Confirm JotForm fields endpoint works
curl -s https://ftmanager.app.n8n.cloud/webhook/v7-jotform-fields | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);console.log('Fields:', r.fields.length)})"

# Confirm admin panel is reachable
curl -sI https://fairytails123.github.io/reportadmin/ | head -1
```

Expected output:
```
Markers: 5
 1: <name> (N mappings)
 2: Playful & Energetic (8 mappings)
 …
Fields: 35
HTTP/2 200
```

If any of these fail, the system is in a broken state — debug before proceeding to Phase 3 work.
