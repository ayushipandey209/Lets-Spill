#!/bin/bash

# ==============================================================================
# GitHub Account Switcher Helper
# ==============================================================================

# ANSI Color codes
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

PERSONAL_USER="ayushipandey209"
PERSONAL_EMAIL="ayushipandey209@users.noreply.github.com"
PERSONAL_NAME="Ayushi Pandey"

OFFICE_USER="AyushiKitab"
OFFICE_EMAIL="ayushikitab@gmail.com"
OFFICE_NAME="Ayushi Pandey"

get_current_status() {
  CURRENT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "Not set")
  CURRENT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "Not set")
  CURRENT_GH_USER=$(gh auth status 2>&1 | grep "Active account: true" -B 2 | head -n 1 | awk '{print $NF}' || echo "Unknown")
}

print_header() {
  clear
  get_current_status
  echo -e "${CYAN}${BOLD}"
  echo "  ██████╗ ██╗████████╗    ███████╗██╗    ██╗██╗████████╗ ██████╗██╗  ██╗"
  echo " ██╔════╝ ██║╚══██╔══╝    ██╔════╝██║    ██║██║╚══██╔══╝██╔════╝██║  ██║"
  echo " ██║  ███╗██║   ██║       ███████╗██║ █╗ ██║██║   ██║   ██║     ███████║"
  echo " ██║   ██║██║   ██║       ╚════██║██║███╗██║██║   ██║   ██║     ██╔══██║"
  echo " ╚██████╔╝██║   ██║       ███████║╚███╔███╔╝██║   ██║   ╚██████╗██║  ██║"
  echo "  ╚═════╝ ╚═╝   ╚═╝       ╚══════╝ ╚══╝╚══╝ ╚═╝   ╚═╝    ╚═════╝╚═╝  ╚═╝"
  echo -e "${NC}"
  echo -e "${BOLD}Current Active Configuration:${NC}"
  echo -e "  • Git Author Name : ${GREEN}${CURRENT_GIT_NAME}${NC}"
  echo -e "  • Git Author Email: ${GREEN}${CURRENT_GIT_EMAIL}${NC}"
  echo -e "  • Active GitHub CLI: ${MAGENTA}${CURRENT_GH_USER}${NC}"
  echo "------------------------------------------------------------------------"
}

switch_to_personal() {
  echo -e "\n${CYAN}>>> Switching to Personal Account (${PERSONAL_USER})...${NC}"
  
  # Switch GitHub CLI account
  if gh auth switch --hostname github.com --user "$PERSONAL_USER" 2>/dev/null; then
    echo -e "${GREEN}✓ GitHub CLI active account switched to: ${BOLD}$PERSONAL_USER${NC}"
  else
    echo -e "${YELLOW}Notice: Could not automatically switch CLI token. Attempting login...${NC}"
    gh auth login -p https -w
  fi

  # Update Git global config
  git config --global user.name "$PERSONAL_NAME"
  git config --global user.email "$PERSONAL_EMAIL"

  echo -e "${GREEN}✓ Git author updated to: ${BOLD}$PERSONAL_NAME <$PERSONAL_EMAIL>${NC}"
  echo -e "\n${GREEN}${BOLD} Successfully switched to Personal Account!${NC}"
  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

switch_to_office() {
  echo -e "\n${CYAN}>>> Switching to Office Account (${OFFICE_USER})...${NC}"
  
  # Switch GitHub CLI account
  if gh auth switch --hostname github.com --user "$OFFICE_USER" 2>/dev/null; then
    echo -e "${GREEN}✓ GitHub CLI active account switched to: ${BOLD}$OFFICE_USER${NC}"
  else
    echo -e "${YELLOW}Notice: Could not automatically switch CLI token. Attempting login...${NC}"
    gh auth login -p https -w
  fi

  # Update Git global config
  git config --global user.name "$OFFICE_NAME"
  git config --global user.email "$OFFICE_EMAIL"

  echo -e "${GREEN}✓ Git author updated to: ${BOLD}$OFFICE_NAME <$OFFICE_EMAIL>${NC}"
  echo -e "\n${GREEN}${BOLD}🏢 Successfully switched to Office Account!${NC}"
  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

show_detailed_status() {
  echo -e "\n${CYAN}================ Full Git & GitHub Status ================${NC}"
  echo -e "${BOLD}Git Global Config:${NC}"
  echo "  user.name  = $(git config --global user.name)"
  echo "  user.email = $(git config --global user.email)"
  echo ""
  echo -e "${BOLD}GitHub CLI Authentication Status:${NC}"
  gh auth status
  echo -e "${CYAN}==========================================================${NC}\n"
  read -n 1 -s -r -p "Press any key to continue..."
}

login_new_account() {
  echo -e "\n${CYAN}>>> Starting GitHub CLI interactive login...${NC}"
  gh auth login -p https -w
  echo ""
  read -n 1 -s -r -p "Press any key to continue..."
}

show_menu() {
  while true; do
    print_header
    echo -e "${BOLD}Choose an action:${NC}\n"
    echo -e "  ${CYAN}[1]${NC} 🏠 Switch to ${BOLD}Personal Account${NC} (${PERSONAL_USER})"
    echo -e "  ${CYAN}[2]${NC} 🏢 Switch to ${BOLD}Office Account${NC}   (${OFFICE_USER})"
    echo -e "  ${CYAN}[3]${NC} 🔍 Show full authentication status (gh auth status)"
    echo -e "  ${CYAN}[4]${NC} 🔑 Log in / Re-authenticate an account"
    echo -e "  ${CYAN}[q]${NC} ❌ Exit"
    echo ""
    echo -n "Enter choice [1-4, q]: "
    read -r choice

    case $choice in
      1)
        switch_to_personal
        ;;
      2)
        switch_to_office
        ;;
      3)
        show_detailed_status
        ;;
      4)
        login_new_account
        ;;
      q|Q)
        echo -e "\n${GREEN}Done. Happy coding!${NC}\n"
        exit 0
        ;;
      *)
        echo -e "\n${RED}Invalid option. Please try again.${NC}"
        sleep 1
        ;;
    esac
  done
}

show_menu
