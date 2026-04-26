#!/usr/bin/env bash
# Dog Report V7 - Transfer Setup Script (Mac/Linux)
# Run on a NEW machine to bootstrap the project from scratch.
#
# One-liner install:
#   curl -fsSL https://raw.githubusercontent.com/Fairytails123/reportadmin/main/setup.sh | bash

set -e

# Colors
C_CYAN='\033[0;36m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_RED='\033[0;31m'
C_GRAY='\033[0;37m'
C_RESET='\033[0m'

header() {
  echo
  echo -e "${C_CYAN}============================================================${C_RESET}"
  echo -e "${C_CYAN}$1${C_RESET}"
  echo -e "${C_CYAN}============================================================${C_RESET}"
}

header "Dog Report V7 - Transfer Setup"

# --- Step 1: Check prerequisites -----------------------------------------
echo -e "\n${C_YELLOW}[1/4] Checking prerequisites...${C_RESET}"

missing=()
command -v git  >/dev/null 2>&1 || missing+=("git (https://git-scm.com/downloads)")
command -v gh   >/dev/null 2>&1 || missing+=("gh (https://cli.github.com/)")
command -v node >/dev/null 2>&1 || missing+=("node (https://nodejs.org)")

if [ ${#missing[@]} -ne 0 ]; then
  echo -e "${C_RED}Missing tools:${C_RESET}"
  for tool in "${missing[@]}"; do
    echo -e "${C_RED}  - $tool${C_RESET}"
  done
  echo -e "\n${C_RED}Install them, then re-run this script.${C_RESET}"
  exit 1
fi
echo -e "${C_GREEN}  git, gh, node all installed.${C_RESET}"

# --- Step 2: GitHub auth -------------------------------------------------
echo -e "\n${C_YELLOW}[2/4] Checking GitHub authentication...${C_RESET}"

if ! gh auth status >/dev/null 2>&1; then
  echo -e "${C_YELLOW}  Not authenticated. Launching gh auth login...${C_RESET}"
  gh auth login
fi
echo -e "${C_GREEN}  GitHub auth OK.${C_RESET}"

# --- Step 3: Clone repo --------------------------------------------------
echo -e "\n${C_YELLOW}[3/4] Cloning project repo...${C_RESET}"

PROJECT_DIR="$HOME/DogReportV7"
if [ -d "$PROJECT_DIR" ]; then
  echo -e "${C_YELLOW}  $PROJECT_DIR already exists. Pulling latest...${C_RESET}"
  (cd "$PROJECT_DIR" && git pull origin main)
else
  gh repo clone Fairytails123/reportadmin "$PROJECT_DIR"
fi
echo -e "${C_GREEN}  Project ready at: $PROJECT_DIR${C_RESET}"

# --- Step 4: Verify system is alive --------------------------------------
echo -e "\n${C_YELLOW}[4/4] Verifying live system...${C_RESET}"

# Check Admin API
if markers_json=$(curl -s --max-time 15 https://ftmanager.app.n8n.cloud/webhook/v7-markers 2>&1); then
  count=$(echo "$markers_json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const r=JSON.parse(d);console.log(r.markers.length)}catch(e){console.log('ERR')}})")
  if [ "$count" != "ERR" ] && [ "$count" != "" ]; then
    echo -e "${C_GREEN}  Admin API: $count markers loaded${C_RESET}"
    echo "$markers_json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{const r=JSON.parse(d);r.markers.forEach(m=>console.log('    Marker '+m.number+': '+m.name+' ('+m.mappings.length+' mappings)'))})"
  else
    echo -e "${C_RED}  Admin API returned invalid JSON${C_RESET}"
  fi
else
  echo -e "${C_RED}  Admin API failed${C_RESET}"
fi

# Check JotForm fields
if fields_json=$(curl -s --max-time 15 https://ftmanager.app.n8n.cloud/webhook/v7-jotform-fields 2>&1); then
  count=$(echo "$fields_json" | node -e "let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>{try{const r=JSON.parse(d);console.log(r.fields.length)}catch(e){console.log('ERR')}})")
  if [ "$count" != "ERR" ] && [ "$count" != "" ]; then
    echo -e "${C_GREEN}  JotForm fields: $count fields available${C_RESET}"
  else
    echo -e "${C_RED}  JotForm fields endpoint returned invalid JSON${C_RESET}"
  fi
else
  echo -e "${C_RED}  JotForm fields endpoint failed${C_RESET}"
fi

# Check admin panel
panel_status=$(curl -sI --max-time 15 https://fairytails123.github.io/reportadmin/ | head -1 | awk '{print $2}')
if [ "$panel_status" = "200" ]; then
  echo -e "${C_GREEN}  Admin panel: HTTP 200${C_RESET}"
else
  echo -e "${C_RED}  Admin panel returned: $panel_status${C_RESET}"
fi

# --- Done ----------------------------------------------------------------
header "Setup Complete"

echo
echo "Project folder: $PROJECT_DIR"
echo
echo "Next steps:"
echo -e "${C_GRAY}  1. Open the folder:    cd $PROJECT_DIR${C_RESET}"
echo -e "${C_GRAY}  2. Read the handoff:   less HANDOFF.md${C_RESET}"
echo -e "${C_GRAY}  3. Start Claude Code:  claude${C_RESET}"
echo
echo "Resume prompt for Claude:"
echo -e "${C_GRAY}  \"Read HANDOFF.md and continue from section 12.4\"${C_RESET}"
echo
echo "Bookmark these n8n URLs:"
echo -e "${C_GRAY}  https://ftmanager.app.n8n.cloud/workflow/jzdMCWVjNLA7AE71  (Setup)${C_RESET}"
echo -e "${C_GRAY}  https://ftmanager.app.n8n.cloud/workflow/kP0HENv1MCxehoaz  (Admin API)${C_RESET}"
echo -e "${C_GRAY}  https://ftmanager.app.n8n.cloud/workflow/ufyIpu25DlYdcaFb  (Telegram Bot)${C_RESET}"
echo
