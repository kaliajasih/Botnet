#!/bin/bash

# ==================================================
#  CEXI RDP MANAGER v3.4 - MULTI-RDP SAFE DELETE
# ==================================================

# ===== COLORS =====
R='\033[1;31m'; G='\033[1;32m'; Y='\033[1;33m'
B='\033[1;34m'; M='\033[1;35m'; C='\033[1;36m'
W='\033[1;37m'; NC='\033[0m'

MY_SERVER_IP=$(curl -s ifconfig.me)

# ===== TYPEWRITER (tanpa beep) =====
typewriter() {
    local text="$1"
    local delay="${2:-0.04}"
    for ((i=0; i<${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo
}

# ===== FUNCTIONS =====
cleanup_ram() {
    echo -e "${Y}[*] Cleaning RAM & zombie processes...${NC}"
    docker stop $(docker ps -q --filter "name=windows") 2>/dev/null
    docker rm $(docker ps -aq --filter "name=windows") 2>/dev/null
    pkill -9 qemu-system-x86 2>/dev/null
    docker volume prune -f >/dev/null
    systemctl restart docker 2>/dev/null
    sync && echo 3 > /proc/sys/vm/drop_caches
    echo -e "${G}[✓] System cleaned${NC}"
}

prepare_system() {
    if ! command -v docker &>/dev/null; then
        echo -e "${Y}[!] Installing Docker...${NC}"
        curl -fsSL https://get.docker.com | sh
    fi
}

header() {
    clear
    echo -e "${M}"
    echo " ██████╗ ██████╗ ██████╗     ██╗   ██╗██████╗ "
    echo " ██╔══██╗██╔══██╗██╔══██╗    ██║   ██║╚════██╗"
    echo " ██████╔╝██║  ██║██████╔╝    ██║   ██║ █████╔╝"
    echo " ██╔══██╗██║  ██║██╔═══╝     ╚██╗ ██╔╝██╔═══╝ "
    echo " ██║  ██║██████╔╝██║          ╚████╔╝ ███████╗"
    echo " ╚═╝  ╚═╝╚═════╝ ╚═╝           ╚═══╝  ╚══════╝"
    echo -e "${W}   RDP MANAGER v3.4 MULTI-RDP${NC}"
    echo -e "${B}------------------------------------------------${NC}"
}

# ===== MAIN =====
prepare_system
header

echo -e "${W}[1] Deploy Windows RDP${NC}"
echo -e "${W}[2] Delete Windows RDP${NC}"
echo -e "${W}[3] Monitor Windows Logs${NC}"
echo -e "${W}[4] Change RDP Password${NC}"
echo -e "${B}------------------------------------------------${NC}"
echo -ne "${Y}Select Option → ${NC}"
read opt

# ===== AUTO GENERATE CONTAINER NAME =====
generate_container_name() {
    count=$(docker ps -aq --filter "name=windows" | wc -l)
    echo "windows$((count + 1))"
}

# ===== SIMPAN DEPLOY INFO =====
DEPLOY_INFO=""

case $opt in
1)
    echo -e "${W}[*] Deploy New Windows RDP${NC}"
    CONTAINER_NAME=$(generate_container_name)
    echo -e "${Y}Container Name → ${G}$CONTAINER_NAME${NC}"

    echo -e "${C}Select Windows Version:${NC}"
    echo " win11   | Windows 11 Pro"
    echo " win10   | Windows 10 Pro"
    echo " tiny11  | Tiny Windows 11"
    echo " 2022    | Windows Server 2022"
    echo -ne "${Y}Choice → ${NC}"; read WIN_VER

    echo -ne "${W}Windows Username (contoh: Administrator) → ${NC}"; read WIN_USER
    echo -ne "${W}Windows Password (contoh: password123) → ${NC}"; read -s WIN_PASS; echo
    echo -ne "${W}RAM (contoh: 6G) → ${NC}"; read RAM
    echo -ne "${W}CPU Cores (contoh: 4) → ${NC}"; read CORES
    echo -ne "${W}Disk (contoh: 50G) → ${NC}"; read DISK
    echo -ne "${Y}Web Port (contoh: 25000, lebih baik >25000) → ${NC}"; read P_WEB
    echo -ne "${Y}RDP Port (contoh: 25001, lebih baik >25000) → ${NC}"; read P_RDP

    ufw allow $P_WEB/tcp >/dev/null
    ufw allow $P_RDP/tcp >/dev/null
    ufw allow $P_RDP/udp >/dev/null

    [ -e /dev/kvm ] && KVM="--device /dev/kvm" || KVM=""

    docker run -d \
        --name $CONTAINER_NAME \
        --privileged \
        $KVM \
        -p $P_WEB:8006 \
        -p $P_RDP:3389 \
        -p $P_RDP:3389/udp \
        -e VERSION="$WIN_VER" \
        -e USERNAME="$WIN_USER" \
        -e PASSWORD="$WIN_PASS" \
        -e RAM_SIZE="$RAM" \
        -e CPU_CORES="$CORES" \
        -e DISK_SIZE="$DISK" \
        --restart always \
        dockurr/windows

    # ===== Hitung deploy ke berapa =====
    DEPLOY_NO=$(docker ps -aq --filter "name=windows" | wc -l)

    # ===== Simpan info deploy untuk ditampilkan nanti =====
    DEPLOY_INFO="[✓] Deploy Windows sukses untuk ke-$DEPLOY_NO
Langkah Lanjutan:
1️⃣ Ke Web dulu → https://$MY_SERVER_IP:$P_WEB
2️⃣ Setelah di Web selesai, lanjut ke APK buka RDP → $MY_SERVER_IP:$P_RDP"
    ;;

2)
    echo -e "${W}Existing Windows Containers:${NC}"
    docker ps --format "{{.Names}}" | grep windows
    echo -ne "${Y}Enter container name to delete (contoh: windows1) → ${NC}"; read DEL_NAME

    # ===== STOP & DELETE SAMPAI KE AKAR =====
    docker stop "$DEL_NAME" >/dev/null 2>&1
    docker rm -v "$DEL_NAME" >/dev/null 2>&1   # -v hapus volume terkait

    # Hapus network container jika ada
    NETWORKS=$(docker inspect --format='{{range $k,$v := .NetworkSettings.Networks}}{{$k}} {{end}}' "$DEL_NAME")
    for net in $NETWORKS; do
        docker network rm "$net" >/dev/null 2>&1
    done

    echo -e "${G}[✓] $DEL_NAME Deleted hingga ke akar${NC}"
    ;;

3)
    echo -e "${W}Existing Windows Containers:${NC}"
    docker ps --format "{{.Names}}" | grep windows
    echo -ne "${Y}Enter container name to monitor (contoh: windows1) → ${NC}"; read MON_NAME
    docker logs -f $MON_NAME
    ;;

4)
    echo -e "${M}=== Change RDP Password ===${NC}"
    echo -e "${W}Existing Windows Containers:${NC}"
    docker ps --format "{{.Names}}" | grep windows
    echo -ne "${Y}Container Name (contoh: windows1) → ${NC}"; read PASS_NAME
    echo -ne "${W}Windows Username (contoh: Administrator) → ${NC}"; read RDP_USER
    echo -ne "${W}New Password (contoh: password123) → ${NC}"; read -s RDP_PASS; echo

    docker exec $PASS_NAME net user "$RDP_USER" "$RDP_PASS" >/dev/null 2>&1
    [ $? -eq 0 ] \
        && echo -e "${G}[✓] Password updated${NC}" \
        || echo -e "${R}[X] Failed${NC}"
    ;;

*)
    ;;
esac

# ===== DARK HACKER ENDING =====
sleep 1
clear
echo -e "${G}"
typewriter "██████╗ ██████╗ ██████╗" 0.002
typewriter "██╔══██╗██╔══██╗██╔══██╗" 0.002
typewriter "██████╔╝██║  ██║██████╔╝" 0.002
typewriter "██╔══██╗██║  ██║██╔═══╝ " 0.002
typewriter "██║  ██║██████╔╝██║     " 0.002
typewriter "╚═╝  ╚═╝╚═════╝ ╚═╝     " 0.002

echo
typewriter "terima kasih telah menggunakan tools ini" 0.05
echo -e "${B}------------------------------------------------${NC}"

# ===== TAMPILKAN DEPLOY INFO SETELAH ENDING =====
if [ ! -z "$DEPLOY_INFO" ]; then
    echo -e "${G}$DEPLOY_INFO${NC}"
    echo -e "${B}------------------------------------------------${NC}"
fi

exit 0
