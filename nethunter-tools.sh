#!/usr/bin/env bash
set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'; BOLD='\033[1m'

ARCH=$(uname -m)
SCRIPT_VERSION="1.0"

REPO_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nethunter-tools"
REPO_CONFIG_FILE="$REPO_CONFIG_DIR/repo.conf"

REPO_URL="http://http.kali.org/kali"
REPO_SUITE="kali-rolling"
REPO_COMPONENTS="main contrib non-free non-free-firmware"
REPO_KEY_URL="https://archive.kali.org/archive-key.asc"
REPO_IS_CONFIGURED=0

# -- helpers ----------------------------------------------------------------
cecho() { printf "$1$2${NC}\n"; }
header() {
    clear 2>/dev/null || true
    printf "${RED}"
    printf "+--------------------------------------------------------------------+\n"
    printf "|   _  __     _       ____        _   _ _____ ____  _   _ _____    |\n"
    printf "|  | |/ /    | |     |  _ \      | \ | |_   _|  _ \| \ | | ____|   |\n"
    printf "|  | ' /     | |     | |_) |     |  \| | | | | |_) |  \| |  _|     |\n"
    printf "|  | . \     | |___  |  __/      | |\  | | | |  _ <| |\  | |___    |\n"
    printf "|  |_|\_\    |_____| |_|         |_| \_| |_| |_| \_\_| \_|_____|   |\n"
    printf "|                                                                    |\n"
    printf "|  _   _ _____ ____  _   _ _____ ____  _____  ____  _   _ _____      |\n"
    printf "| | \ | |_   _|  _ \| \ | |_   _|_   _| ____|  _ \| \ | | ____|    |\n"
    printf "| |  \| | | | | |_) |  \| | | |   | | |  _| | |_) |  \| |  _|      |\n"
    printf "| | |\  | | | |  _ <| |\  | | |   | | | |___|  _ <| |\  | |___     |\n"
    printf "| |_| \_| |_| |_| \_\_| \_| |_|   |_| |_____|_| \_\_| \_|_____|    |\n"
    printf "|                                                                    |\n"
    printf "${GREEN}|           ARM64 Tool Installer v%s                          |\n" "$SCRIPT_VERSION"
    printf "|       For rooted Android + Termux + Debian                         |\n"
    printf "${RED}+--------------------------------------------------------------------+${NC}\n"
    printf "\n"
}

# -- checks -----------------------------------------------------------------
check_env() {
    # Inside proot-distro Debian
    if [[ -f /etc/debian_version ]] && command -v apt-get &>/dev/null; then
        return 0
    fi

    # In Termux native? Detect by looking for $TERMUX_VERSION or the Termux prefix
    if [[ -n "${TERMUX_VERSION:-}" ]] || [[ -d /data/data/com.termux ]]; then
        if command -v proot-distro &>/dev/null; then
            if proot-distro list 2>/dev/null | grep -qi "debian"; then
                local spath
                spath=$(realpath "$0" 2>/dev/null || readlink -f "$0" 2>/dev/null || echo "$0")
                printf "\n${YELLOW}[*] Re-running inside proot-distro Debian...${NC}\n"
                exec proot-distro login debian -- bash "$spath"
                # exec replaces the process; if we reach here, it failed
                printf "\n${RED}[!] Failed to enter proot-distro Debian.${NC}\n"
                exit 1
            fi
        fi
        printf "\n${RED}[!] proot-distro Debian not found.${NC}\n"
        printf "    Install it with:\n"
        printf "      pkg install proot-distro\n"
        printf "      proot-distro install debian\n"
        printf "      proot-distro login debian\n"
        exit 1
    fi

    # Unknown environment
    printf "\n${YELLOW}[!] Unknown environment. Expecting Termux + proot-distro Debian.${NC}\n"
    printf "    Continuing anyway...\n"
    sleep 2
}

check_arch() {
    if [[ "$ARCH" != "aarch64" ]]; then
        cecho "$RED" "[!] This script is for ARM64 (aarch64) only. Detected: $ARCH"
        exit 1
    fi
}

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        cecho "$RED" "[!] Root privileges required. Run with sudo or as root."
        exit 1
    fi
}

check_apt() {
    if ! command -v apt-get &>/dev/null; then
        cecho "$RED" "[!] apt-get not found. This script requires Debian/Ubuntu with apt."
        exit 1
    fi
}

# -- repo config persistence ------------------------------------------------
load_repo_config() {
    if [[ -f "$REPO_CONFIG_FILE" ]]; then
        source "$REPO_CONFIG_FILE"
        REPO_IS_CONFIGURED=1
    fi
}

save_repo_config() {
    mkdir -p "$REPO_CONFIG_DIR"
    cat > "$REPO_CONFIG_FILE" <<-EOF
		REPO_URL="$REPO_URL"
		REPO_SUITE="$REPO_SUITE"
		REPO_COMPONENTS="$REPO_COMPONENTS"
		REPO_KEY_URL="$REPO_KEY_URL"
	EOF
}

# -- repo management --------------------------------------------------------
repo_configured() {
    [[ "$REPO_IS_CONFIGURED" -eq 1 ]] && [[ -f /etc/apt/sources.list.d/custom-repo.list ]]
}

configure_repo() {
    while true; do
        header
        cecho "$CYAN" "+------------------------------------------------------------------+"
        cecho "$CYAN" "|                       Repository Configuration                    |"
        cecho "$CYAN" "+------------------------------------------------------------------+"
        printf "\n"
        printf "  Current settings:\n"
        printf "    URL:       %s\n" "$REPO_URL"
        printf "    Suite:     %s\n" "$REPO_SUITE"
        printf "    Comps:     %s\n" "$REPO_COMPONENTS"
        printf "    Key URL:   %s\n" "$REPO_KEY_URL"
        printf "\n"
        printf "  ${CYAN}1${NC}) Change repo settings and add to apt\n"
        printf "  ${CYAN}2${NC}) Remove repo from apt sources\n"
        printf "  ${CYAN}b${NC}) Back to main menu\n"
        printf "\n"
        read -rp "  Choose [1, 2, b]: " repo_choice

        case "$repo_choice" in
            1)
                printf "\n"
                printf "  ${YELLOW}Enter new values or press Enter to keep current:${NC}\n"
                printf "\n"
                read -rp "  Repository URL [$REPO_URL]: " new_url
                REPO_URL="${new_url:-$REPO_URL}"
                read -rp "  Suite [$REPO_SUITE]: " new_suite
                REPO_SUITE="${new_suite:-$REPO_SUITE}"
                read -rp "  Components [$REPO_COMPONENTS]: " new_comps
                REPO_COMPONENTS="${new_comps:-$REPO_COMPONENTS}"
                read -rp "  GPG key URL [$REPO_KEY_URL]: " new_key
                REPO_KEY_URL="${new_key:-$REPO_KEY_URL}"

                save_repo_config
                printf "\n"
                cecho "$GREEN" "[+] Config saved. Now adding repo to apt..."
                printf "\n"

                # make sure keyring dir exists
                mkdir -p /usr/share/keyrings 2>/dev/null || true

                # ensure apt is usable
                apt-get update 2>/dev/null || true
                apt-get install -y gnupg curl wget 2>/dev/null || true

                local keyring="/usr/share/keyrings/custom-repo.gpg"
                if [[ -n "$REPO_KEY_URL" ]]; then
                    printf "  ${YELLOW}[*] Downloading GPG key...${NC}\n"
                    if ! wget -q -O- "$REPO_KEY_URL" 2>/dev/null | gpg --dearmor -o "$keyring" 2>/dev/null; then
                        printf "  ${YELLOW}[!] GPG key download failed (non-fatal). Adding repo unsigned.${NC}\n"
                    fi
                fi

                local list="/etc/apt/sources.list.d/custom-repo.list"
                local signed=""
                if [[ -f "$keyring" ]]; then
                    signed="[signed-by=$keyring]"
                fi
                echo "deb $signed $REPO_URL $REPO_SUITE $REPO_COMPONENTS" > "$list"

                local pref="/etc/apt/preferences.d/custom-repo.pref"
                cat > "$pref" <<-EOFPP
					Package: *
					Pin: release o=*
					Pin-Priority: 100
				EOFPP

                printf "  ${YELLOW}[*] Updating package lists...${NC}\n"
                if apt-get update; then
                    REPO_IS_CONFIGURED=1
                    printf "\n"
                    cecho "$GREEN" "[+] Repository added and configured."
                    cecho "$GREEN" "[+] You can now install tools from the Browse menu."
                else
                    printf "\n"
                    cecho "$YELLOW" "[!] apt update had warnings. The repo was added but check your settings."
                    REPO_IS_CONFIGURED=1
                fi
                sleep 2
                ;;
            2)
                printf "\n"
                rm -f /etc/apt/sources.list.d/custom-repo.list
                rm -f /etc/apt/preferences.d/custom-repo.pref
                rm -f /usr/share/keyrings/custom-repo.gpg
                apt-get update 2>/dev/null || true
                printf "\n"
                cecho "$GREEN" "[+] Repository removed from apt sources."
                sleep 2
                ;;
            b|B) return 0 ;;
            *) cecho "$RED" "[!] Invalid option."; sleep 1 ;;
        esac
    done
}

update_packages() {
    header
    cecho "$YELLOW" "[*] Updating package lists..."
    apt-get update
    printf "\n"
    cecho "$GREEN" "[+] Done."
    printf "\n"
    read -rp "  Press Enter to return to menu..."
}

# -- tool database ----------------------------------------------------------
get_categories() {
    cat <<-EOF
	1) Information Gathering
	2) Vulnerability Analysis
	3) Wireless Attacks
	4) Exploitation Tools
	5) Forensics
	6) Sniffing and Spoofing
	7) Password Attacks
	8) Maintaining Access
	9) Reverse Engineering
	10) Reporting Tools
	11) Stress Testing
	12) Hardware Attacks
	EOF
}

get_tools_for_category() {
    case "$1" in
        1) echo "nmap dnsutils enum4linux gobuster wfuzz netdiscover nikto recon-ng theharvester dnsrecon dnsenum whois whatweb wpscan sublist3r amass masscan dmitry" ;;
        2) echo "sqlmap dirb wapiti zaproxy commix legion nikto openvas jboss-autopwn" ;;
        3) echo "aircrack-ng kismet reaver bully fern-wifi-cracker wifite pixiewps mdk4" ;;
        4) echo "metasploit-framework exploitdb hydra medusa ncrack searchsploit beef-xss shellnoob cymothoa sbd" ;;
        5) echo "binwalk foremost testdisk sleuthkit autopsy volatility ddrescue guymager bulk-extractor scalpel" ;;
        6) echo "wireshark tcpdump dsniff mitmproxy ettercap bettercap responder tshark" ;;
        7) echo "john hashcat hydra crunch cewl hash-identifier ophcrack wordlists rsmangler maskprocessor" ;;
        8) echo "webshells weevely shellter powersploit mimikatz backdoor-factory" ;;
        9) echo "apktool dex2jar jadx radare2 edb-debugger binutils strace ltrace gdb" ;;
        10) echo "cutycapt dradis faraday keepnote cherrytree maltego" ;;
        11) echo "hping3 macof siege slowhttptest thc-ssl-dos t50" ;;
        12) echo "minicom ubertooth bluelog bluesnarfer redfang spooftooph killerbee rfdump" ;;
        *) echo "" ;;
    esac
}

get_category_name() {
    case "$1" in
        1) echo "Information Gathering";; 2) echo "Vulnerability Analysis";;
        3) echo "Wireless Attacks";;      4) echo "Exploitation Tools";;
        5) echo "Forensics";;             6) echo "Sniffing and Spoofing";;
        7) echo "Password Attacks";;      8) echo "Maintaining Access";;
        9) echo "Reverse Engineering";;   10) echo "Reporting Tools";;
        11) echo "Stress Testing";;       12) echo "Hardware Attacks";;
        *) echo "Unknown";;
    esac
}

get_description() {
    local t="$1"
    case "$t" in
        nmap)       echo "Network discovery and security auditing tool" ;;
        dnsutils)   echo "DNS client utilities (dig, nslookup, nsupdate)" ;;
        enum4linux) echo "Windows/Samba enumeration from Linux" ;;
        gobuster)   echo "Directory/file and DNS subdomain brute-forcer" ;;
        wfuzz)      echo "Web application fuzzer and brute-forcer" ;;
        netdiscover) echo "Network address discovery scanner" ;;
        nikto)      echo "Web server vulnerability scanner" ;;
        recon-ng)   echo "Full-featured web reconnaissance framework" ;;
        theharvester) echo "Email, subdomain and people harvesting tool" ;;
        dnsrecon)   echo "DNS enumeration and scan tool" ;;
        dnsenum)    echo "DNS enumeration utility" ;;
        whois)      echo "Domain registration information lookup" ;;
        whatweb)    echo "Website fingerprinting and detection" ;;
        wpscan)     echo "WordPress vulnerability scanner" ;;
        sublist3r)  echo "Fast subdomain enumeration tool" ;;
        amass)      echo "In-depth subdomain discovery and recon" ;;
        masscan)    echo "Massive TCP port scanner (fast as masscan)" ;;
        dmitry)     echo "Deepmagic Information Gathering Tool" ;;
        sqlmap)     echo "SQL injection detection and exploitation" ;;
        dirb)       echo "Web content scanner / directory brute-forcer" ;;
        wapiti)     echo "Web application vulnerability scanner" ;;
        zaproxy)    echo "OWASP Zed Attack Proxy - web app scanner" ;;
        commix)     echo "Command injection exploitation tool" ;;
        legion)     echo "Security auditing and enumeration framework" ;;
        openvas)    echo "Open Vulnerability Assessment System" ;;
        jboss-autopwn) echo "JBoss vulnerability scanner and exploiter" ;;
        aircrack-ng) echo "802.11 WEP/WPA/WPA2 cracking suite" ;;
        kismet)     echo "Wireless network detector and sniffer" ;;
        reaver)     echo "WPS brute-force attack tool" ;;
        bully)      echo "WPS brute-force attack tool (alternative)" ;;
        fern-wifi-cracker) echo "Wireless security auditing tool" ;;
        wifite)     echo "Automated wireless network auditor" ;;
        pixiewps)   echo "Offline WPS PIN brute-forcer" ;;
        mdk4)       echo "Wireless penetration testing tool" ;;
        metasploit-framework) echo "Penetration testing framework and exploit development" ;;
        exploitdb)  echo "Public exploit database archive" ;;
        hydra)      echo "Parallel network login cracker (many protocols)" ;;
        medusa)     echo "Parallel network login auditor" ;;
        ncrack)     echo "High-speed network authentication cracker" ;;
        searchsploit) echo "Exploit Database search tool" ;;
        beef-xss)   echo "Browser Exploitation Framework (MITM)" ;;
        shellnoob)  echo "Shellcode writing helper and debugger" ;;
        cymothoa)   echo "Shellcode injection tool into running processes" ;;
        sbd)        echo "Secure backdoor and network connection tool" ;;
        binwalk)    echo "Firmware analysis and extraction tool" ;;
        foremost)   echo "File carving and recovery tool" ;;
        testdisk)   echo "Partition recovery and undelete tool" ;;
        sleuthkit)  echo "Filesystem forensic analysis toolkit" ;;
        autopsy)    echo "Digital forensics GUI (uses SleuthKit)" ;;
        volatility) echo "Memory forensics analysis framework" ;;
        ddrescue)   echo "Data recovery tool for damaged media" ;;
        guymager)   echo "Forensic disk imaging tool" ;;
        bulk-extractor) echo "Digital forensics feature extraction tool" ;;
        scalpel)    echo "Fast file carver for forensic recovery" ;;
        wireshark)  echo "Network protocol analysis and packet capture" ;;
        tcpdump)    echo "Command-line packet capture and analysis" ;;
        dsniff)     echo "Network sniffing toolkit (MITM, password capture)" ;;
        mitmproxy)  echo "Interactive HTTPS man-in-the-middle proxy" ;;
        ettercap)   echo "Powerful MITM attack suite" ;;
        bettercap)  echo "Modern MITM framework and network monitor" ;;
        responder)  echo "LLMNR/NBT-NS/mDNS poisoner and NTLM hash capture" ;;
        tshark)     echo "CLI network protocol analyzer (Wireshark engine)" ;;
        john)       echo "John the Ripper - offline password cracking" ;;
        hashcat)    echo "Advanced GPU-accelerated password recovery" ;;
        crunch)     echo "Custom wordlist generator" ;;
        cewl)       echo "Custom wordlist generator from web content" ;;
        hash-identifier) echo "Hash type identification tool" ;;
        ophcrack)   echo "Windows LM/NTLM hash cracker (rainbow tables)" ;;
        wordlists)  echo "Collection of password wordlists" ;;
        rsmangler)  echo "Wordlist mangling and generation tool" ;;
        maskprocessor) echo "High-performance word generator with masks" ;;
        webshells)  echo "Collection of web shells for various platforms" ;;
        weevely)    echo "PHP webshell and post-exploitation tool" ;;
        shellter)   echo "Dynamic shellcode injection tool" ;;
        powersploit) echo "PowerShell post-exploitation framework" ;;
        mimikatz)   echo "Windows credential extraction tool" ;;
        backdoor-factory) echo "Patch PE/ELF binaries with backdoors" ;;
        apktool)    echo "Android APK reverse engineering tool" ;;
        dex2jar)    echo "Convert DEX to JAR for Android analysis" ;;
        jadx)       echo "Dex-to-Java decompiler with GUI" ;;
        radare2)    echo "Advanced reverse engineering framework" ;;
        edb-debugger) echo "Cross-platform Qt-based debugger" ;;
        binutils)   echo "GNU binary utilities (objdump, readelf, strings)" ;;
        strace)     echo "System call tracer for debugging" ;;
        ltrace)     echo "Library call tracer for debugging" ;;
        gdb)        echo "GNU debugger for binary analysis" ;;
        cutycapt)   echo "Web page screenshot capture utility" ;;
        dradis)     echo "Collaborative reporting and knowledge base" ;;
        faraday)    echo "Collaborative penetration test management" ;;
        keepnote)   echo "Cross-platform note-taking application" ;;
        cherrytree) echo "Hierarchical note-taking with rich formatting" ;;
        maltego)    echo "Open-source intelligence and forensics (CE)" ;;
        hping3)     echo "Network packet crafting and stress testing" ;;
        macof)      echo "MAC address flooding tool (switch DoS)" ;;
        siege)      echo "HTTP load testing and benchmarking" ;;
        slowhttptest) echo "Slow HTTP DoS attack testing tool" ;;
        thc-ssl-dos) echo "SSL/TLS denial-of-service testing" ;;
        t50)        echo "Multi-protocol network stress testing" ;;
        minicom)    echo "Serial communication terminal" ;;
        ubertooth)  echo "Bluetooth testing and monitoring (Ubertooth)" ;;
        bluelog)    echo "Bluetooth device discovery and logging" ;;
        bluesnarfer) echo "Bluetooth device data extraction" ;;
        redfang)    echo "Bluetooth device discovery tool" ;;
        spooftooph) echo "Bluetooth device spoofing tool" ;;
        killerbee)  echo "ZigBee/802.15.4 security testing" ;;
        rfdump)     echo "RFID tag data dumping tool" ;;
        *)          echo "No description available for: $t" ;;
    esac
}

# -- search -----------------------------------------------------------------
search_tool() {
    header
    cecho "$CYAN" "+------------------------------------------------------------------+"
    cecho "$CYAN" "|                          Search Tools                             |"
    cecho "$CYAN" "+------------------------------------------------------------------+"
    printf "\n"
    read -rp "  Search for a tool (name or keyword): " query
    printf "\n"

    if [[ -z "$query" ]]; then
        cecho "$YELLOW" "[i] No search term entered."
        printf "\n"
        read -rp "  Press Enter to return..."
        return
    fi

    local found=0
    for cat_id in $(seq 1 12); do
        local cname=$(get_category_name "$cat_id")
        for tool in $(get_tools_for_category "$cat_id"); do
            if echo "$tool" | grep -iq "$query"; then
                if [[ $found -eq 0 ]]; then
                    cecho "$GREEN" "  Results for '$query':"
                    printf "\n"
                fi
                local desc=$(get_description "$tool")
                printf "    ${CYAN}%-22s${NC} %s\n" "$tool" "$desc"
                ((found++))
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        cecho "$YELLOW" "[i] No matching tools found for '$query'."
    else
        printf "\n"
        cecho "$GREEN" "[+] $found match(es) found."
    fi
    printf "\n"
    read -rp "  Press Enter to return to menu..."
}

# -- installed tools --------------------------------------------------------
show_installed() {
    header
    cecho "$CYAN" "+------------------------------------------------------------------+"
    cecho "$CYAN" "|                    Installed NetHunter Tools                      |"
    cecho "$CYAN" "+------------------------------------------------------------------+"
    printf "\n"

    local all_tools=""
    for cat_id in $(seq 1 12); do
        all_tools="$all_tools $(get_tools_for_category "$cat_id")"
    done

    local count=0
    for tool in $all_tools; do
        if dpkg -l "$tool" 2>/dev/null | grep -q '^ii'; then
            local desc=$(get_description "$tool")
            printf "  ${GREEN}[*]${NC} ${CYAN}%-22s${NC} %s\n" "$tool" "$desc"
            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        cecho "$YELLOW" "[i] No Kali NetHunter tools are currently installed."
    else
        printf "\n"
        cecho "$GREEN" "[+] $count tool(s) installed."
    fi
    printf "\n"
    read -rp "  Press Enter to return to menu..."
}

# -- install a tool ---------------------------------------------------------
install_tool() {
    local tool="$1"
    local desc=$(get_description "$tool")

    header
    cecho "$CYAN" "+------------------------------------------------------------------+"
    printf "|${NC}                         ${BOLD}Tool: %s${NC}                        |\n" "$tool"
    cecho "$CYAN" "+------------------------------------------------------------------+"
    printf "\n"
    printf "  ${BOLD}Description:${NC} %s\n" "$desc"
    printf "\n"

    if ! repo_configured; then
        cecho "$YELLOW" "[!] No repository is configured."
        cecho "$YELLOW" "[!] Use option 1 from the main menu first."
        printf "\n"
        read -rp "  Press Enter to return..."
        return
    fi

    if dpkg -l "$tool" 2>/dev/null | grep -q '^ii'; then
        cecho "$GREEN" "[+] $tool is already installed."
        printf "\n"
        read -rp "  Press Enter to return..."
        return
    fi

    printf "${YELLOW}[*] About to install: $tool${NC}\n"
    printf "\n"
    read -rp "  Proceed with installation? [Y/n]: " confirm
    confirm="${confirm:-Y}"

    if [[ "$confirm" =~ ^[Yy] ]]; then
        printf "\n"
        cecho "$YELLOW" "[*] Installing $tool..."
        apt-get install -y "$tool" 2>&1 | tail -5
        printf "\n"
        cecho "$GREEN" "[+] Installation complete: $tool"
    else
        printf "\n"
        cecho "$YELLOW" "[i] Skipped."
    fi
    printf "\n"
    read -rp "  Press Enter to return..."
}

# -- browse category --------------------------------------------------------
browse_category() {
    local cat_id="$1"
    local cname=$(get_category_name "$cat_id")

    while true; do
        header
        cecho "$CYAN" "+------------------------------------------------------------------+"
        printf "|${NC}                      ${BOLD}Category: %s${NC}                        |\n" "$cname"
        cecho "$CYAN" "+------------------------------------------------------------------+"
        printf "\n"

        local tools=$(get_tools_for_category "$cat_id")
        if [[ -z "$tools" ]]; then
            cecho "$YELLOW" "[i] No tools defined for this category."
            printf "\n"
            read -rp "  Press Enter to return..."
            return
        fi

        local i=0
        local tool_list=()
        for t in $tools; do
            ((i++))
            tool_list+=("$t")
            local desc=$(get_description "$t")
            printf "  ${CYAN}%2d)${NC} ${BOLD}%-22s${NC} %s\n" "$i" "$t" "$desc"
        done

        printf "\n"
        printf "  ${YELLOW}b${NC}) Back to category menu\n"
        printf "  ${YELLOW}m${NC}) Main menu\n"
        printf "\n"
        read -rp "  Select a tool [1-$i, b, m]: " choice

        case "$choice" in
            m) return 2 ;;
            b) return 0 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i )); then
                    local selected="${tool_list[$((choice-1))]}"
                    cat_id_global="$cat_id"
                    install_tool "$selected"
                else
                    cecho "$RED" "[!] Invalid option."
                    sleep 1
                fi
                ;;
        esac
    done
}

# -- category menu ----------------------------------------------------------
category_menu() {
    while true; do
        header
        cecho "$CYAN" "+------------------------------------------------------------------+"
        cecho "$CYAN" "|                         Tool Categories                           |"
        cecho "$CYAN" "+------------------------------------------------------------------+"
        printf "\n"
        cecho "$YELLOW" "  Select a category:"
        printf "\n"

        local cats=$(get_categories)
        local i=0
        while IFS= read -r line; do
            ((i++))
            printf "  ${CYAN}%2d${NC}) %s\n" "$i" "${line#??}"
        done <<< "$cats"

        printf "\n"
        printf "  ${YELLOW}m${NC}) Main menu\n"
        printf "\n"
        read -rp "  Select category [1-$i, m]: " choice

        case "$choice" in
            m) return 0 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i )); then
                    browse_category "$choice"
                    local ret=$?
                    [[ $ret -eq 2 ]] && return 0
                else
                    cecho "$RED" "[!] Invalid option."
                    sleep 1
                fi
                ;;
        esac
    done
}

# -- main menu --------------------------------------------------------------
main_menu() {
    while true; do
        header
        cecho "$GREEN" "+------------------------------------------------------------------+"
        cecho "$GREEN" "|                          Main Menu                               |"
        cecho "$GREEN" "+------------------------------------------------------------------+"
        printf "\n"
        printf "  ${CYAN}1${NC}) Configure Repository\n"
        printf "  ${CYAN}2${NC}) Browse Tools by Category\n"
        printf "  ${CYAN}3${NC}) Search for a Tool\n"
        printf "  ${CYAN}4${NC}) Update Package Lists\n"
        printf "  ${CYAN}5${NC}) Show Installed NetHunter Tools\n"
        printf "  ${CYAN}e${NC}) Exit\n"
        printf "\n"

        if repo_configured; then
            printf "  ${GREEN}[+] Repo: configured${NC}\n"
        else
            printf "  ${RED}[x] Repo: not configured${NC}\n"
        fi
        printf "  ${BLUE}[i] Architecture: $ARCH${NC}\n"
        printf "\n"
        read -rp "  Select option [1-5, e]: " choice

        case "$choice" in
            1) configure_repo ;;
            2) category_menu ;;
            3) search_tool ;;
            4) update_packages ;;
            5) show_installed ;;
            e|E)
                printf "\n"
                cecho "$GREEN" "[+] Exiting. Stay sharp."
                exit 0
                ;;
            *)
                cecho "$RED" "[!] Invalid option."
                sleep 1
                ;;
        esac
    done
}

# -- entry point ------------------------------------------------------------
main() {
    check_arch
    check_root
    check_apt
    load_repo_config
    main_menu
}

main
