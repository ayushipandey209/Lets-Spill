#!/bin/bash

# ==============================================================================
# Let's Spill — Android Runner & Build Helper Script
# ==============================================================================

set -e

# ANSI Color codes
BOLD='\033[1m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

print_banner() {
  clear
  echo -e "${CYAN}${BOLD}"
  echo "  ██╗     ███████╗████████╗███████╗    ███████╗██████╗ ██╗██╗     ██╗     "
  echo "  ██║     ██╔════╝╚══██╔══╝██╔════╝    ██╔════╝██╔══██╗██║██║     ██║     "
  echo "  ██║     █████╗     ██║   ███████╗    ███████╗██████╔╝██║██║     ██║     "
  echo "  ██║     ██╔══╝     ██║   ╚════██║    ╚════██║██╔═══╝ ██║██║     ██║     "
  echo "  ███████╗███████╗   ██║   ███████║    ███████║██║     ██║███████╗███████╗"
  echo "  ╚══════╝╚══════╝   ╚═╝   ╚══════╝    ╚══════╝╚═╝     ╚═╝╚══════╝╚══════╝"
  echo -e "${NC}"
  echo -e "${BOLD}Let's Spill — Android App Management Menu${NC}"
  echo "----------------------------------------------------"
}

# Function to get active android device/emulator ID
find_android_device() {
  # 1. Try finding via adb
  local adb_dev=$(adb devices 2>/dev/null | grep -w "device" | grep -v "List" | awk '{print $1}' | head -n 1)
  if [ -n "$adb_dev" ]; then
    echo "$adb_dev"
    return
  fi

  # 2. Try finding via flutter devices
  local flutter_dev=$(flutter devices 2>/dev/null | grep -i "android" | awk -F'•' '{print $2}' | tr -d ' ' | head -n 1)
  if [ -n "$flutter_dev" ]; then
    echo "$flutter_dev"
    return
  fi

  echo ""
}

# Function to run on Android Emulator
run_android_emulator() {
  echo -e "\n${CYAN}>>> Checking for running Android devices/emulators...${NC}"
  
  TARGET_DEVICE=$(find_android_device)
  
  if [ -n "$TARGET_DEVICE" ]; then
    echo -e "${GREEN}✓ Found active Android device: ${BOLD}$TARGET_DEVICE${NC}"
  else
    echo -e "${YELLOW}No running Android emulator found. Attempting to launch Pixel_9a / default AVD...${NC}"
    flutter emulators --launch Pixel_9a 2>/dev/null || flutter emulators --launch $(flutter emulators | grep android | awk '{print $1}' | head -n 1) || true
    
    echo -e "${CYAN}Waiting for emulator to initialize...${NC}"
    for i in {1..12}; do
      sleep 2
      TARGET_DEVICE=$(find_android_device)
      if [ -n "$TARGET_DEVICE" ]; then
        break
      fi
    done
  fi

  if [ -z "$TARGET_DEVICE" ]; then
    TARGET_DEVICE="android"
  fi

  echo -e "\n${GREEN}>>> Launching Let's Spill on Android ($TARGET_DEVICE)...${NC}"
  flutter run -d "$TARGET_DEVICE"
}

# Function to run on Connected Physical/Other Device
run_connected_device() {
  echo -e "\n${CYAN}>>> Scanning for connected devices...${NC}"
  echo ""
  flutter devices
  echo ""
  echo -e "${YELLOW}Enter the Device ID from the list above (or press Enter for default):${NC} "
  read -r DEVICE_ID
  
  if [ -z "$DEVICE_ID" ]; then
    echo -e "${GREEN}>>> Launching on default device...${NC}"
    flutter run
  else
    echo -e "${GREEN}>>> Launching on $DEVICE_ID...${NC}"
    flutter run -d "$DEVICE_ID"
  fi
}

# Function to build for Google Play Store (App Bundle)
build_playstore_bundle() {
  echo -e "\n${CYAN}====================================================${NC}"
  echo -e "${BOLD}${GREEN}Building Release App Bundle (.aab) for Google Play Store${NC}"
  echo -e "${CYAN}====================================================${NC}\n"
  
  echo -e "${YELLOW}1. Cleaning previous build artifacts...${NC}"
  flutter clean
  flutter pub get

  echo -e "\n${YELLOW}2. Compiling Android App Bundle in release mode...${NC}"
  flutter build appbundle --release

  echo -e "\n${GREEN}====================================================${NC}"
  echo -e "${BOLD}✓ Build Complete!${NC}"
  echo -e "Your Play Store bundle is ready at:"
  echo -e "${CYAN}${BOLD}$(pwd)/build/app/outputs/bundle/release/app-release.aab${NC}"
  echo -e "${GREEN}====================================================${NC}\n"
}

# Function to build Release APK (for direct testing/distribution)
build_release_apk() {
  echo -e "\n${CYAN}====================================================${NC}"
  echo -e "${BOLD}${GREEN}Building Release APK (.apk) for Direct Install${NC}"
  echo -e "${CYAN}====================================================${NC}\n"

  echo -e "${YELLOW}1. Fetching dependencies...${NC}"
  flutter pub get

  echo -e "\n${YELLOW}2. Compiling Release APK...${NC}"
  flutter build apk --release

  echo -e "\n${GREEN}====================================================${NC}"
  echo -e "${BOLD}✓ Build Complete!${NC}"
  echo -e "Your Release APK is ready at:"
  echo -e "${CYAN}${BOLD}$(pwd)/build/app/outputs/flutter-apk/app-release.apk${NC}"
  echo -e "${GREEN}====================================================${NC}\n"
}

# Main Menu
show_menu() {
  print_banner
  echo -e "${BOLD}Please select an option:${NC}\n"
  echo -e "  ${CYAN}[1]${NC} 📱 Run on ${BOLD}Android Emulator${NC} (Pixel 9a / Active Emulator)"
  echo -e "  ${CYAN}[2]${NC} 🔌 Run on ${BOLD}Connected Physical Device / Specific Target${NC}"
  echo -e "  ${CYAN}[3]${NC} 📦 Build ${BOLD}Release App Bundle (.aab)${NC} for Google Play Store"
  echo -e "  ${CYAN}[4]${NC} 📲 Build ${BOLD}Release APK (.apk)${NC} for direct installation"
  echo -e "  ${CYAN}[5]${NC} 🧹 Run Flutter Clean & Get Dependencies"
  echo -e "  ${CYAN}[6]${NC} 🔄 Switch ${BOLD}Git / GitHub Account${NC} (Personal / Office)"
  echo -e "  ${CYAN}[q]${NC} ❌ Quit"
  echo ""
  echo -n "Enter choice [1-6, q]: "
  read -r choice

  case $choice in
    1)
      run_android_emulator
      ;;
    2)
      run_connected_device
      ;;
    3)
      build_playstore_bundle
      ;;
    4)
      build_release_apk
      ;;
    5)
      echo -e "\n${CYAN}Cleaning and updating packages...${NC}"
      flutter clean
      flutter pub get
      echo -e "${GREEN}✓ Done!${NC}"
      ;;
    6)
      ./switch_git.sh
      show_menu
      ;;
    q|Q)
      echo -e "\n${YELLOW}Goodbye!${NC}"
      exit 0
      ;;
    *)
      echo -e "\n${RED}Invalid option. Please try again.${NC}"
      sleep 2
      show_menu
      ;;
  esac
}

show_menu
