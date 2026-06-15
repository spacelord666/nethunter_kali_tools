#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# Kali NetHunter ARM64 Tool Installer
# For rooted Android devices running Debian through Termux
# ============================================================================

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
WHITE='\033[1;37m'; NC='\033[0m'; BOLD='\033[1m'

ARCH=$(uname -m)
SCRIPT_VERSION="1.0"

# Repo config (persisted to file, loaded on startup)
REPO_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/nethunter-tools"
REPO_CONFIG_FILE="$REPO_CONFIG_DIR/repo.conf"

# Session-level repo values (defaults used if no config file)
REPO_URL="http://http.kali.org/kali"
REPO_SUITE="kali-rolling"
REPO_COMPONENTS="main contrib non-free non-free-firmware"
REPO_KEY_URL="https://archive.kali.org/archive-key.asc"
REPO_IS_CONFIGURED=0

# ---------------------------------------------------------------------------
# ASCII Logo
# ---------------------------------------------------------------------------
logo() {
    clear
    echo -e "${RED}"
    echo '╔══════════════════════════════════════════════════════════╗'
    echo '║   ██╗  ██╗ █████╗ ██╗     ██╗    ███╗   ██╗███████╗   ║'
    echo '║   ██║ ██╔╝██╔══██╗██║     ██║    ████╗  ██║██╔════╝   ║'
    echo '║   █████╔╝ ███████║██║     ██║    ██╔██╗ ██║█████╗     ║'
    echo '║   ██╔═██╗ ██╔══██║██║     ██║    ██║╚██╗██║██╔══╝     ║'
    echo '║   ██║  ██╗██║  ██║███████╗██║    ██║ ╚████║███████╗   ║'
    echo '║   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝    ╚═╝  ╚═══╝╚══════╝   ║'
    echo '║                                                          ║'
    echo '║   ████████╗██╗  ██╗██╗   ██╗███╗   ██╗████████╗███████╗║'
    echo '║   ╚══██╔══╝██║  ██║██║   ██║████╗  ██║╚══██╔══╝██╔════╝║'
    echo '║      ██║   ███████║██║   ██║██╔██╗ ██║   ██║   █████╗  ║'
    echo '║      ██║   ██╔══██║██║   ██║██║╚██╗██║   ██║   ██╔══╝  ║'
    echo '║      ██║   ██║  ██║╚██████╔╝██║ ╚████║   ██║   ███████╗║'
    echo '║      ╚═╝   ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝║'
    echo '║                                                          ║'
    echo -e "${GREEN}║       ARM64 Tool Installer v${SCRIPT_VERSION}              ║"
    echo '║   For rooted Android + Termux + Debian                   ║'
    echo -e "${RED}╚══════════════════════════════════════════════════════════╝${NC}"
    echo
}

# ---------------------------------------------------------------------------
# Prerequisites checks
# ---------------------------------------------------------------------------
check_arch() {
    if [[ "$ARCH" != "aarch64" ]]; then
        echo -e "${RED}[!] This script is for ARM64 (aarch64) only. Detected: $ARCH${NC}"
        exit 1
    fi
}

check_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        echo -e "${RED}[!] Root privileges required. Run with sudo or as root.${NC}"
        exit 1
    fi
}

check_apt() {
    if ! command -v apt &>/dev/null; then
        echo -e "${RED}[!] apt not found. This script requires Debian/Ubuntu with apt.${NC}"
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# Repo config persistence
# ---------------------------------------------------------------------------
load_repo_config() {
    if [[ -f "$REPO_CONFIG_FILE" ]]; then
        source "$REPO_CONFIG_FILE"
        REPO_IS_CONFIGURED=1
        return 0
    fi
    return 1
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

# ---------------------------------------------------------------------------
# Repository management
# ---------------------------------------------------------------------------
repo_configured() {
    if [[ "$REPO_IS_CONFIGURED" -eq 1 ]] && \
       ls /etc/apt/sources.list.d/*.list /etc/apt/sources.list 2>/dev/null | \
       xargs grep -rls "kali.org\|$REPO_URL" 2>/dev/null | grep -q .; then
        return 0
    fi
    return 1
}

configure_repo() {
    while true; do
        logo
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e " ${BOLD}Configure Repository${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo
        echo -e "  ${YELLOW}Current configuration:${NC}"
        echo -e "  ${BLUE}URL:       ${NC}$REPO_URL"
        echo -e "  ${BLUE}Suite:     ${NC}$REPO_SUITE"
        echo -e "  ${BLUE}Comps:     ${NC}$REPO_COMPONENTS"
        echo -e "  ${BLUE}Key URL:   ${NC}$REPO_KEY_URL"
        echo
        echo -e "  ${YELLOW}What would you like to do?${NC}"
        echo
        echo -e "  ${CYAN}1)${NC}  Enter new repo details"
        echo -e "  ${CYAN}2)${NC}  Download GPG key and add repo to apt"
        echo -e "  ${CYAN}3)${NC}  Remove repo from apt sources"
        echo -e "  ${CYAN}b)${NC}  Back to main menu"
        echo
        read -rp "Select option [1-3, b]: " repo_choice

        case "$repo_choice" in
            1)
                echo
                read -rp "Repository URL [$REPO_URL]: " new_url
                REPO_URL="${new_url:-$REPO_URL}"
                read -rp "Suite [$REPO_SUITE]: " new_suite
                REPO_SUITE="${new_suite:-$REPO_SUITE}"
                read -rp "Components [$REPO_COMPONENTS]: " new_comps
                REPO_COMPONENTS="${new_comps:-$REPO_COMPONENTS}"
                read -rp "GPG key URL [$REPO_KEY_URL]: " new_key
                REPO_KEY_URL="${new_key:-$REPO_KEY_URL}"

                save_repo_config
                REPO_IS_CONFIGURED=1
                echo
                echo -e "${GREEN}[+] Repo configuration saved.${NC}"
                echo -e "${YELLOW}[i] Use option 2 to add it to apt sources.${NC}"
                sleep 2
                ;;
            2)
                echo
                apt update
                apt install -y gnupg curl wget

                local keyring="/usr/share/keyrings/custom-repo.gpg"
                if [[ -n "$REPO_KEY_URL" ]]; then
                    echo -e "${YELLOW}[*] Downloading GPG key...${NC}"
                    wget -q -O- "$REPO_KEY_URL" | gpg --dearmor -o "$keyring" 2>/dev/null || {
                        echo -e "${RED}[!] Failed to download GPG key. Try a different URL.${NC}"
                        sleep 2
                        continue
                    }
                fi

                local list="/etc/apt/sources.list.d/custom-repo.list"
                local signed=""
                if [[ -f "$keyring" ]]; then
                    signed="[signed-by=$keyring]"
                fi
                echo "deb $signed $REPO_URL $REPO_SUITE $REPO_COMPONENTS" > "$list"

                echo -e "${YELLOW}[*] Setting up APT pinning (priority 100)...${NC}"

                local pref="/etc/apt/preferences.d/custom-repo.pref"
                cat > "$pref" <<-EOFPP
					Package: *
					Pin: release o=*
					Pin-Priority: 100
				EOFPP

                echo -e "${YELLOW}[*] Updating package lists...${NC}"
                apt update

                save_repo_config
                REPO_IS_CONFIGURED=1
                echo
                echo -e "${GREEN}[+] Repository added to apt sources.${NC}"
                echo -e "${YELLOW}[i] You can now install tools from this repo.${NC}"
                sleep 2
                ;;
            3)
                echo
                rm -f /etc/apt/sources.list.d/custom-repo.list
                rm -f /etc/apt/preferences.d/custom-repo.pref
                rm -f /usr/share/keyrings/custom-repo.gpg
                apt update
                echo
                echo -e "${GREEN}[+] Repository removed from apt sources.${NC}"
                sleep 2
                ;;
            b|B) return 0 ;;
            *) echo -e "${RED}[!] Invalid option.${NC}"; sleep 1 ;;
        esac
    done
}

update_packages() {
    logo
    echo -e "${YELLOW}[*] Updating package lists...${NC}"
    apt update
    echo
    echo -e "${GREEN}[+] Done.${NC}"
    echo
    read -rp "Press Enter to return to menu..."
}

# ---------------------------------------------------------------------------
# Tool database
# ---------------------------------------------------------------------------
get_categories() {
    cat <<-EOF
	1) Information Gathering
	2) Vulnerability Analysis
	3) Wireless Attacks
	4) Exploitation Tools
	5) Forensics
	6) Sniffing & Spoofing
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
        5) echo "Forensics";;             6) echo "Sniffing & Spoofing";;
        7) echo "Password Attacks";;      8) echo "Maintaining Access";;
        9) echo "Reverse Engineering";;   10) echo "Reporting Tools";;
        11) echo "Stress Testing";;       12) echo "Hardware Attacks";;
        *) echo "Unknown";;
    esac
}

get_description() {
    local t="$1"
    case "$t" in
        # -- Information Gathering --
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

        # -- Vulnerability Analysis --
        sqlmap)     echo "SQL injection detection and exploitation" ;;
        dirb)       echo "Web content scanner / directory brute-forcer" ;;
        wapiti)     echo "Web application vulnerability scanner" ;;
        zaproxy)    echo "OWASP Zed Attack Proxy - web app scanner" ;;
        commix)     echo "Command injection exploitation tool" ;;
        legion)     echo "Security auditing and enumeration framework" ;;
        openvas)    echo "Open Vulnerability Assessment System" ;;
        jboss-autopwn) echo "JBoss vulnerability scanner and exploiter" ;;

        # -- Wireless Attacks --
        aircrack-ng) echo "802.11 WEP/WPA/WPA2 cracking suite" ;;
        kismet)     echo "Wireless network detector and sniffer" ;;
        reaver)     echo "WPS brute-force attack tool" ;;
        bully)      echo "WPS brute-force attack tool (alternative)" ;;
        fern-wifi-cracker) echo "Wireless security auditing tool" ;;
        wifite)     echo "Automated wireless network auditor" ;;
        pixiewps)   echo "Offline WPS PIN brute-forcer" ;;
        mdk4)       echo "Wireless penetration testing tool" ;;

        # -- Exploitation Tools --
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

        # -- Forensics --
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

        # -- Sniffing & Spoofing --
        wireshark)  echo "Network protocol analysis and packet capture" ;;
        tcpdump)    echo "Command-line packet capture and analysis" ;;
        dsniff)     echo "Network sniffing toolkit (MITM, password capture)" ;;
        mitmproxy)  echo "Interactive HTTPS man-in-the-middle proxy" ;;
        ettercap)   echo "Powerful MITM attack suite" ;;
        bettercap)  echo "Modern MITM framework and network monitor" ;;
        responder)  echo "LLMNR/NBT-NS/mDNS poisoner and NTLM hash capture" ;;
        tshark)     echo "CLI network protocol analyzer (Wireshark engine)" ;;

        # -- Password Attacks --
        john)       echo "John the Ripper - offline password cracking" ;;
        hashcat)    echo "Advanced GPU-accelerated password recovery" ;;
        crunch)     echo "Custom wordlist generator" ;;
        cewl)       echo "Custom wordlist generator from web content" ;;
        hash-identifier) echo "Hash type identification tool" ;;
        ophcrack)   echo "Windows LM/NTLM hash cracker (rainbow tables)" ;;
        wordlists)  echo "Collection of password wordlists" ;;
        rsmangler)  echo "Wordlist mangling and generation tool" ;;
        maskprocessor) echo "High-performance word generator with masks" ;;

        # -- Maintaining Access --
        webshells)  echo "Collection of web shells for various platforms" ;;
        weevely)    echo "PHP webshell and post-exploitation tool" ;;
        shellter)   echo "Dynamic shellcode injection tool" ;;
        powersploit) echo "PowerShell post-exploitation framework" ;;
        mimikatz)   echo "Windows credential extraction tool" ;;
        backdoor-factory) echo "Patch PE/ELF binaries with backdoors" ;;

        # -- Reverse Engineering --
        apktool)    echo "Android APK reverse engineering tool" ;;
        dex2jar)    echo "Convert DEX to JAR for Android analysis" ;;
        jadx)       echo "Dex-to-Java decompiler with GUI" ;;
        radare2)    echo "Advanced reverse engineering framework" ;;
        edb-debugger) echo "Cross-platform Qt-based debugger" ;;
        binutils)   echo "GNU binary utilities (objdump, readelf, strings)" ;;
        strace)     echo "System call tracer for debugging" ;;
        ltrace)     echo "Library call tracer for debugging" ;;
        gdb)        echo "GNU debugger for binary analysis" ;;

        # -- Reporting Tools --
        cutycapt)   echo "Web page screenshot capture utility" ;;
        dradis)     echo "Collaborative reporting and knowledge base" ;;
        faraday)    echo "Collaborative penetration test management" ;;
        keepnote)   echo "Cross-platform note-taking application" ;;
        cherrytree) echo "Hierarchical note-taking with rich formatting" ;;
        maltego)    echo "Open-source intelligence and forensics (CE)" ;;

        # -- Stress Testing --
        hping3)     echo "Network packet crafting and stress testing" ;;
        macof)      echo "MAC address flooding tool (switch DoS)" ;;
        siege)      echo "HTTP load testing and benchmarking" ;;
        slowhttptest) echo "Slow HTTP DoS attack testing tool" ;;
        thc-ssl-dos) echo "SSL/TLS denial-of-service testing" ;;
        t50)        echo "Multi-protocol network stress testing" ;;

        # -- Hardware Attacks --
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

# ---------------------------------------------------------------------------
# Search tool
# ---------------------------------------------------------------------------
search_tool() {
    logo
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e " ${BOLD}Search Tools${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo
    read -rp "Search for a tool (name or keyword): " query
    echo

    if [[ -z "$query" ]]; then
        echo -e "${YELLOW}[i] No search term entered.${NC}"
        echo
        read -rp "Press Enter to return..."
        return
    fi

    local found=0
    for cat_id in $(seq 1 12); do
        local cname
        cname=$(get_category_name "$cat_id")
        for tool in $(get_tools_for_category "$cat_id"); do
            if echo "$tool" | grep -iq "$query"; then
                if [[ $found -eq 0 ]]; then
                    echo -e "${GREEN}Results for '$query':${NC}"
                    echo
                fi
                local desc
                desc=$(get_description "$tool")
                printf "  ${CYAN}%-22s${NC} %s\n" "$tool" "$desc"
                ((found++))
            fi
        done
    done

    if [[ $found -eq 0 ]]; then
        echo -e "${YELLOW}[i] No matching tools found for '$query'.${NC}"
    else
        echo
        echo -e "${GREEN}[+] $found match(es) found.${NC}"
    fi

    echo
    read -rp "Press Enter to return to menu..."
}

# ---------------------------------------------------------------------------
# Show installed tools
# ---------------------------------------------------------------------------
show_installed() {
    logo
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e " ${BOLD}Installed NetHunter Tools${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo

    local all_tools=""
    for cat_id in $(seq 1 12); do
        all_tools="$all_tools $(get_tools_for_category "$cat_id")"
    done

    local count=0
    for tool in $all_tools; do
        if dpkg -l "$tool" 2>/dev/null | grep -q '^ii'; then
            local desc
            desc=$(get_description "$tool")
            printf "  ${GREEN}✔${NC} ${CYAN}%-22s${NC} %s\n" "$tool" "$desc"
            ((count++))
        fi
    done

    if [[ $count -eq 0 ]]; then
        echo -e "${YELLOW}[i] No Kali NetHunter tools are currently installed.${NC}"
    else
        echo
        echo -e "${GREEN}[+] $count tool(s) installed.${NC}"
    fi

    echo
    read -rp "Press Enter to return to menu..."
}

# ---------------------------------------------------------------------------
# Install a single tool with confirmation and info
# ---------------------------------------------------------------------------
install_tool() {
    local tool="$1"
    local desc
    desc=$(get_description "$tool")

    logo
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo -e " ${BOLD}Tool: $tool${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════${NC}"
    echo
    echo -e "  ${BOLD}Description:${NC} $desc"
    echo

    if ! repo_configured; then
        echo -e "${YELLOW}[!] No repository is configured.${NC}"
        echo -e "${YELLOW}[!] Use option 1 from the main menu first.${NC}"
        echo
        read -rp "Press Enter to return..."
        return
    fi

    if dpkg -l "$tool" 2>/dev/null | grep -q '^ii'; then
        echo -e "${GREEN}[+] $tool is already installed.${NC}"
        echo
        read -rp "Press Enter to return..."
        return
    fi

    echo -e "${YELLOW}[*] About to install: $tool${NC}"
    echo -e "${YELLOW}[*] Category: $(echo $(get_category_name "$cat_id_global" 2>/dev/null || echo "N/A"))${NC}"
    echo
    read -rp "Proceed with installation? [Y/n]: " confirm
    confirm="${confirm:-Y}"

    if [[ "$confirm" =~ ^[Yy] ]]; then
        echo
        echo -e "${YELLOW}[*] Installing $tool...${NC}"
        apt install -y "$tool" 2>&1 | tail -5
        echo
        echo -e "${GREEN}[+] Installation complete: $tool${NC}"
    else
        echo
        echo -e "${YELLOW}[i] Skipped.${NC}"
    fi

    echo
    read -rp "Press Enter to return..."
}

# ---------------------------------------------------------------------------
# Browse a category
# ---------------------------------------------------------------------------
browse_category() {
    local cat_id="$1"
    local cname
    cname=$(get_category_name "$cat_id")

    while true; do
        logo
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e " ${BOLD}Category: $cname${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo

        local tools
        tools=$(get_tools_for_category "$cat_id")
        if [[ -z "$tools" ]]; then
            echo -e "${YELLOW}[i] No tools defined for this category.${NC}"
            echo
            read -rp "Press Enter to return..."
            return
        fi

        local i=0
        local tool_list=()
        for t in $tools; do
            ((i++))
            tool_list+=("$t")
            local desc
            desc=$(get_description "$t")
            printf "  ${CYAN}%2d)${NC} ${BOLD}%-22s${NC} %s\n" "$i" "$t" "$desc"
        done

        echo
        echo -e "  ${YELLOW}b)${NC} Back to category menu"
        echo -e "  ${YELLOW}m)${NC} Main menu"
        echo
        read -rp "Select a tool [1-$i, b, m]: " choice

        case "$choice" in
            m) return 2 ;;
            b) return 0 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i )); then
                    local selected="${tool_list[$((choice-1))]}"
                    cat_id_global="$cat_id"
                    install_tool "$selected"
                else
                    echo -e "${RED}[!] Invalid option.${NC}"
                    sleep 1
                fi
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Category selection menu
# ---------------------------------------------------------------------------
category_menu() {
    while true; do
        logo
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo -e " ${BOLD}Tool Categories${NC}"
        echo -e "${CYAN}═══════════════════════════════════════════${NC}"
        echo
        echo -e "  ${YELLOW}Select a category:${NC}"
        echo

        local cats
        cats=$(get_categories)
        local i=0
        local cat_ids=()
        while IFS= read -r line; do
            ((i++))
            cat_ids+=("$i")
            printf "  ${CYAN}%2d)${NC} %s\n" "$i" "${line#??}"
        done <<< "$cats"

        echo
        echo -e "  ${YELLOW}m)${NC} Main menu"
        echo
        read -rp "Select category [1-$i, m]: " choice

        case "$choice" in
            m) return 0 ;;
            *)
                if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= i )); then
                    browse_category "$choice"
                    local ret=$?
                    [[ $ret -eq 2 ]] && return 0
                else
                    echo -e "${RED}[!] Invalid option.${NC}"
                    sleep 1
                fi
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Main menu
# ---------------------------------------------------------------------------
main_menu() {
    while true; do
        logo
        echo -e "${GREEN}═══════════════════════════════════════════${NC}"
        echo -e " ${BOLD}Main Menu${NC}"
        echo -e "${GREEN}═══════════════════════════════════════════${NC}"
        echo
        echo -e "  ${CYAN}1)${NC}  Configure Repository"
        echo -e "  ${CYAN}2)${NC}  Browse Tools by Category"
        echo -e "  ${CYAN}3)${NC}  Search for a Tool"
        echo -e "  ${CYAN}4)${NC}  Update Package Lists"
        echo -e "  ${CYAN}5)${NC}  Show Installed NetHunter Tools"
        echo -e "  ${CYAN}e)${NC}  Exit"
        echo

        if repo_configured; then
            echo -e "  ${GREEN}[✓] Repo: configured${NC}"
        else
            echo -e "  ${RED}[✗] Repo: not configured${NC}"
        fi
        echo -e "  ${BLUE}[i] Architecture: $ARCH${NC}"
        echo
        read -rp "Select option [1-5, e]: " choice

        case "$choice" in
            1) configure_repo ;;
            2) category_menu ;;
            3) search_tool ;;
            4) update_packages ;;
            5) show_installed ;;
            e|E)
                echo
                echo -e "${GREEN}[+] Exiting. Stay sharp.${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}[!] Invalid option.${NC}"
                sleep 1
                ;;
        esac
    done
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main() {
    check_arch
    check_root
    check_apt
    load_repo_config
    main_menu
}

main
