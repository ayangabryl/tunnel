#!/bin/sh
# tunnel installer - works on macOS and Linux (Ubuntu/PopOS)
# curl -fsSL https://raw.githubusercontent.com/ayangabryl/tunnel/main/install.sh | sh

set -e

TUNNEL_DIR="$HOME/.tunnel"
TUNNEL_BIN="$TUNNEL_DIR/tunnel"
VERSION="1.0.0"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

print_banner() {
    echo ""
    echo "  ${ORANGE}${BOLD}tunnel${NC} ${DIM}installer${NC}"
    echo "  ${DIM}reverse ssh tunnel cli${NC}"
    echo ""
}

print_step() {
    echo "  ${CYAN}→${NC} $1"
}

print_ok() {
    echo "  ${GREEN}✓${NC} $1"
}

print_err() {
    echo "  ${RED}✗${NC} $1"
    exit 1
}

detect_os() {
    case "$(uname -s)" in
        Darwin*)  echo "macos" ;;
        Linux*)   echo "linux" ;;
        *)        echo "unknown" ;;
    esac
}

detect_shell() {
    if [ -n "$ZSH_VERSION" ]; then
        echo "zsh"
    elif [ -n "$BASH_VERSION" ]; then
        echo "bash"
    else
        basename "$SHELL"
    fi
}

get_shell_rc() {
    local shell="$1"
    case "$shell" in
        zsh)  echo "$HOME/.zshrc" ;;
        bash)
            if [ -f "$HOME/.bashrc" ]; then
                echo "$HOME/.bashrc"
            else
                echo "$HOME/.bash_profile"
            fi
            ;;
        *)    echo "$HOME/.profile" ;;
    esac
}

cleanup_old() {
    # Remove old oh-my-zsh tunnel script
    if [ -f "$HOME/.oh-my-zsh/custom/auto-tunnel.sh" ]; then
        rm -f "$HOME/.oh-my-zsh/custom/auto-tunnel.sh"
        print_ok "Removed old oh-my-zsh tunnel script"
    fi

    # Remove old tunnel alias from shell rc
    local rc="$1"
    if grep -q 'alias tunnel=' "$rc" 2>/dev/null; then
        # Create backup
        cp "$rc" "$rc.backup"
        # Remove the alias line
        if [ "$(detect_os)" = "macos" ]; then
            sed -i '' '/alias tunnel=/d' "$rc"
            sed -i '' '/# SSH tunnel alias/d' "$rc"
        else
            sed -i '/alias tunnel=/d' "$rc"
            sed -i '/# SSH tunnel alias/d' "$rc"
        fi
        print_ok "Removed old tunnel alias from $rc"
    fi
}

main() {
    print_banner

    OS=$(detect_os)
    SHELL_TYPE=$(detect_shell)
    SHELL_RC=$(get_shell_rc "$SHELL_TYPE")

    print_step "Detected: $OS with $SHELL_TYPE"

    # Cleanup old installations
    print_step "Cleaning up old installations..."
    cleanup_old "$SHELL_RC"

    # Create directory
    print_step "Creating $TUNNEL_DIR..."
    mkdir -p "$TUNNEL_DIR"

    # Download tunnel script
    print_step "Downloading tunnel v$VERSION..."

    # Download/create the tunnel script
    cat > "$TUNNEL_BIN" << 'TUNNEL_SCRIPT'
#!/usr/bin/env zsh

VERSION="1.0.0"
CONFIG_DIR="$HOME/.tunnel"
CONFIG_FILE="$CONFIG_DIR/config"

DIM=$'\033[2m'
BOLD=$'\033[1m'
NC=$'\033[0m'
ORANGE=$'\033[38;5;214m'
GREEN=$'\033[38;5;114m'
RED=$'\033[38;5;203m'
CYAN=$'\033[38;5;80m'
GRAY=$'\033[38;5;245m'

REMOTE_HOST=""
REMOTE_USER=""
REMOTE_PORT=""
LOCAL_PORT=""

load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

save_config() {
    cat > "$CONFIG_FILE" << EOF
REMOTE_HOST="$REMOTE_HOST"
REMOTE_USER="$REMOTE_USER"
REMOTE_PORT="$REMOTE_PORT"
LOCAL_PORT="$LOCAL_PORT"
EOF
}

setup() {
    clear
    print ""
    print "  ${ORANGE}${BOLD}tunnel${NC} ${DIM}v${VERSION}${NC}"
    print "  ${DIM}first time setup${NC}"
    print ""
    print "  ${DIM}Configure your reverse SSH tunnel settings.${NC}"
    print "  ${DIM}You can change these later with: tunnel --config${NC}"
    print ""

    print -n "  ${CYAN}Remote host${NC} ${DIM}(e.g. 107.155.113.61):${NC} "
    read REMOTE_HOST
    [[ -z "$REMOTE_HOST" ]] && { print "  ${RED}Remote host is required${NC}"; exit 1; }

    print -n "  ${CYAN}Remote user${NC} ${DIM}(default: root):${NC} "
    read REMOTE_USER
    [[ -z "$REMOTE_USER" ]] && REMOTE_USER="root"

    print -n "  ${CYAN}Remote port${NC} ${DIM}(e.g. 4004):${NC} "
    read REMOTE_PORT
    [[ -z "$REMOTE_PORT" ]] && { print "  ${RED}Remote port is required${NC}"; exit 1; }

    print -n "  ${CYAN}Local port${NC} ${DIM}(default: 443):${NC} "
    read LOCAL_PORT
    [[ -z "$LOCAL_PORT" ]] && LOCAL_PORT="443"

    print ""
    print "  ${DIM}─────────────────────────────────${NC}"
    print "  ${CYAN}Remote:${NC} $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
    print "  ${CYAN}Local:${NC}  localhost:$LOCAL_PORT"
    print "  ${DIM}─────────────────────────────────${NC}"
    print ""
    print -n "  ${DIM}Save? [Y/n]:${NC} "
    read confirm

    [[ "$confirm" == "n" ]] || [[ "$confirm" == "N" ]] && { print "  ${RED}Cancelled${NC}"; exit 1; }

    save_config
    print ""
    print "  ${GREEN}✓${NC} Saved to ${DIM}$CONFIG_FILE${NC}"
    print "  ${DIM}Run 'tunnel' to start${NC}"
    print ""
}

show_usage() {
    print ""
    print "  ${ORANGE}${BOLD}tunnel${NC} ${DIM}v${VERSION}${NC}"
    print "  ${DIM}reverse ssh tunnel with auto-reconnect${NC}"
    print ""
    print "  ${CYAN}${BOLD}Usage:${NC}"
    print "    tunnel              ${DIM}start the tunnel${NC}"
    print "    tunnel --config     ${DIM}reconfigure settings${NC}"
    print "    tunnel --show       ${DIM}show current config${NC}"
    print "    tunnel --version    ${DIM}show version${NC}"
    print "    tunnel --help       ${DIM}show this help${NC}"
    print ""
}

show_config() {
    load_config || { print "  ${RED}No config.${NC} Run: tunnel --config"; exit 1; }
    print ""
    print "  ${ORANGE}${BOLD}Configuration${NC} ${DIM}($CONFIG_FILE)${NC}"
    print "  ${CYAN}Remote:${NC} $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"
    print "  ${CYAN}Local:${NC}  localhost:$LOCAL_PORT"
    print ""
}

case "$1" in
    --config|-c) setup; exit 0 ;;
    --show|-s) show_config; exit 0 ;;
    --version|-v) print "tunnel v${VERSION}"; exit 0 ;;
    --help|-h) show_usage; exit 0 ;;
    "") ;;
    *) print "  ${RED}Unknown:${NC} $1"; show_usage; exit 1 ;;
esac

load_config || { setup; exit 0; }
[[ -z "$REMOTE_HOST" ]] || [[ -z "$REMOTE_PORT" ]] && { print "  ${RED}Invalid config.${NC} Run: tunnel --config"; exit 1; }

SSH_PID=""
CONNECTED=false
CONNECT_TIME=0
COMMANDS=("/help" "/status" "/info" "/kill" "/reconnect" "/clear" "/quit")
COMMAND_DESC=("show commands" "connection status" "tunnel config" "kill port" "force reconnect" "clear screen" "exit")
TIPS=("type /help for commands" "press ctrl+c to stop" "auto-reconnects on disconnect" "tunnel --config to change settings")

hide_cursor() { print -n '\033[?25l'; }
show_cursor() { print -n '\033[?25h'; }
stty -echoctl 2>/dev/null

spin() {
    local msg="$1" frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏") i=1
    hide_cursor
    while true; do
        print -n "\r\033[K  ${ORANGE}${frames[$i]}${NC} ${msg}"
        i=$((i % 10 + 1)); sleep 0.1
    done
}

status_ok() { print -n "\r\033[K"; show_cursor; print "  ${GREEN}✓${NC} $1 ${DIM}$2${NC}"; }
status_err() { print -n "\r\033[K"; show_cursor; print "  ${RED}✗${NC} $1 ${DIM}$2${NC}"; }
status_warn() { print -n "\r\033[K"; show_cursor; print "  ${ORANGE}●${NC} $1 ${DIM}$2${NC}"; }

format_duration() {
    local s=$1
    [[ $s -lt 60 ]] && { print "${s}s"; return; }
    [[ $s -lt 3600 ]] && { print "$((s/60))m $((s%60))s"; return; }
    print "$((s/3600))h $((s%3600/60))m"
}

restore_terminal() { show_cursor; stty sane 2>/dev/null; }

cleanup_and_exit() {
    kill %% 2>/dev/null; print -n "\r\033[K"; print ""
    print "  ${ORANGE}●${NC} stopping..."
    [[ -n "$SSH_PID" ]] && kill $SSH_PID 2>/dev/null
    pkill -f "ssh.*$REMOTE_HOST.*-R.*$REMOTE_PORT" 2>/dev/null
    ssh -o ConnectTimeout=3 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "fuser -k $REMOTE_PORT/tcp 2>/dev/null" 2>/dev/null
    print "  ${GREEN}✓${NC} stopped"; print ""
    restore_terminal; exit 0
}

trap cleanup_and_exit INT TERM
trap restore_terminal EXIT

cleanup_remote() {
    ssh -o ConnectTimeout=5 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "fuser -k $REMOTE_PORT/tcp 2>/dev/null; sleep 1" 2>/dev/null
    sleep 2
}

show_help() { print "  ${ORANGE}${BOLD}Commands${NC}"; for i in {1..${#COMMANDS[@]}}; do print "  ${CYAN}${COMMANDS[$i]}${NC} ${DIM}${COMMAND_DESC[$i]}${NC}"; done; }
show_status() { [[ "$CONNECTED" == true ]] && print "  ${GREEN}●${NC} ${BOLD}connected${NC} ${DIM}$(format_duration $(($(date +%s)-CONNECT_TIME)))${NC}" || print "  ${RED}●${NC} ${BOLD}disconnected${NC}"; }
show_info() { print "  ${ORANGE}${BOLD}Config${NC}"; print "  ${DIM}Remote:${NC} $REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT"; print "  ${DIM}Local:${NC} localhost:$LOCAL_PORT"; }

kill_port() {
    local p="$1"
    [[ -z "$p" ]] && { print "  ${RED}usage:${NC} /kill <port>"; return; }
    [[ ! "$p" =~ ^[0-9]+$ ]] && { print "  ${RED}invalid:${NC} $p"; return; }
    print "  ${ORANGE}●${NC} killing port $p..."
    ssh -o ConnectTimeout=5 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "fuser -k $p/tcp 2>/dev/null" 2>/dev/null
    print "  ${GREEN}✓${NC} port $p killed"
}

get_suggestion() { for c in "${COMMANDS[@]}"; do [[ "$c" == ${1}* ]] && [[ "$c" != "$1" ]] && { print "${c#$1}"; return; }; done; }

handle_command() {
    local cmd="$1" args="${cmd#* }" base="${cmd%% *}"
    case "$base" in
        /help|/h) show_help ;;
        /status|/s) show_status ;;
        /info|/i) show_info ;;
        /kill|/k) [[ "$cmd" == "$base" ]] && kill_port "" || kill_port "$args" ;;
        /quit|/q|/exit) cleanup_and_exit ;;
        /reconnect|/r) CONNECTED=false; return 1 ;;
        /clear|/c) clear; show_header; [[ "$CONNECTED" == true ]] && print "  ${GREEN}✓${NC} connected" ;;
        "") ;;
        /*) print "  ${RED}unknown:${NC} $cmd" ;;
        *) print "  ${DIM}use / for commands${NC}" ;;
    esac; return 0
}

show_header() {
    print ""; print "  ${ORANGE}${BOLD}tunnel${NC} ${DIM}v${VERSION}${NC}"
    print "  ${DIM}reverse ssh tunnel with auto-reconnect${NC}"
    print "  ${DIM}by ${CYAN}ayangabryl${NC}"; print ""
    print "  ${CYAN}│${NC} ${DIM}$REMOTE_USER@$REMOTE_HOST:$REMOTE_PORT ← localhost:$LOCAL_PORT${NC}"; print ""
}

do_connect() {
    spin "preparing..." & local spin_pid=$!
    cleanup_remote
    kill $spin_pid 2>/dev/null; wait $spin_pid 2>/dev/null

    spin "connecting..." & spin_pid=$!
    local ssh_out=$(mktemp)
    ssh $REMOTE_USER@$REMOTE_HOST -nN -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -o TCPKeepAlive=yes -o ConnectTimeout=10 -o ExitOnForwardFailure=yes -R $REMOTE_PORT:127.0.0.1:$LOCAL_PORT 2>"$ssh_out" &
    SSH_PID=$!

    local waited=0
    while kill -0 $SSH_PID 2>/dev/null && [[ $waited -lt 15 ]]; do
        ssh -o ConnectTimeout=3 -o BatchMode=yes $REMOTE_USER@$REMOTE_HOST "ss -tln | grep -q ':$REMOTE_PORT '" 2>/dev/null && {
            CONNECTED=true; CONNECT_TIME=$(date +%s)
            kill $spin_pid 2>/dev/null; wait $spin_pid 2>/dev/null
            rm -f "$ssh_out"; return 0
        }
        grep -q "Permission denied\|Connection refused\|port forwarding failed" "$ssh_out" 2>/dev/null && {
            kill $SSH_PID $spin_pid 2>/dev/null; wait $spin_pid 2>/dev/null
            rm -f "$ssh_out"; return 1
        }
        sleep 0.5; waited=$((waited + 1))
    done
    kill $SSH_PID $spin_pid 2>/dev/null; wait $spin_pid 2>/dev/null
    rm -f "$ssh_out"; return 1
}

check_tunnel() { [[ -n "$SSH_PID" ]] && kill -0 $SSH_PID 2>/dev/null && return 0; CONNECTED=false; return 1; }

clear; show_header
attempt=1

while true; do
    if [[ "$CONNECTED" == false ]]; then
        [[ $attempt -gt 1 ]] && print "  ${CYAN}│${NC} ${DIM}retry #$((attempt-1))${NC}"
        if do_connect; then
            status_ok "${GREEN}connected${NC}" "localhost:$LOCAL_PORT → $REMOTE_HOST:$REMOTE_PORT"
            attempt=1
        else
            status_err "${RED}failed${NC}" "retrying..."; attempt=$((attempt+1)); sleep 3; continue
        fi
    fi

    local tip="${TIPS[$((RANDOM % ${#TIPS[@]} + 1))]}"
    print "  ${DIM}└ Tip: ${tip}${NC}"
    print -n "  ${DIM}>${NC} "

    local input="" old_stty=$(stty -g 2>/dev/null)
    stty -echo -icanon min 0 time 10 2>/dev/null

    while true; do
        local char=""; read -k 1 char 2>/dev/null
        if [[ -n "$char" ]]; then
            if [[ "$char" == $'\n' ]] || [[ "$char" == $'\r' ]]; then
                print ""
                if [[ -n "$input" ]]; then
                    stty "$old_stty" 2>/dev/null
                    handle_command "$input" || break
                    stty -echo -icanon min 0 time 10 2>/dev/null
                fi
                input=""; print -n "  ${DIM}>${NC} "
            elif [[ "$char" == $'\x7f' ]] || [[ "$char" == $'\b' ]]; then
                [[ -n "$input" ]] && { input="${input%?}"; print -n "\r\033[K  ${DIM}>${NC} ${input}"; [[ "$input" == /* ]] && { local h=$(get_suggestion "$input"); [[ -n "$h" ]] && print -n "${GRAY}${h}${NC}"; }; }
            elif [[ "$char" == $'\t' ]]; then
                [[ "$input" == /* ]] && for c in "${COMMANDS[@]}"; do [[ "$c" == ${input}* ]] && { input="$c"; print -n "\r\033[K  ${DIM}>${NC} ${input}"; break; }; done
            elif [[ "$char" == $'\e' ]]; then
                input=""; print -n "\r\033[K  ${DIM}>${NC} "
            elif [[ "$char" != $'\x00' ]]; then
                input+="$char"; print -n "\r\033[K  ${DIM}>${NC} ${input}"
                [[ "$input" == /* ]] && { local h=$(get_suggestion "$input"); [[ -n "$h" ]] && print -n "${GRAY}${h}${NC}"; }
            fi
        fi
        check_tunnel || {
            stty "$old_stty" 2>/dev/null; print ""
            local d=""; [[ $CONNECT_TIME -gt 0 ]] && d="after $(format_duration $(($(date +%s)-CONNECT_TIME)))"
            status_warn "${ORANGE}disconnected${NC}" "$d"; print ""
            spin "reconnecting in 3s..." & local sp=$!; sleep 3
            kill $sp 2>/dev/null; wait $sp 2>/dev/null; print -n "\r\033[K"
            attempt=$((attempt+1)); break
        }
    done
    stty "$old_stty" 2>/dev/null
done
TUNNEL_SCRIPT

    chmod +x "$TUNNEL_BIN"
    print_ok "Downloaded tunnel"

    # Add to PATH
    print_step "Adding to $SHELL_RC..."

    # Check if already added
    if grep -q "/.tunnel" "$SHELL_RC" 2>/dev/null; then
        print_ok "Already in PATH"
    else
        echo '' >> "$SHELL_RC"
        echo '# tunnel cli' >> "$SHELL_RC"
        echo 'export PATH="$HOME/.tunnel:$PATH"' >> "$SHELL_RC"
        print_ok "Added to PATH"
    fi

    echo ""
    echo "  ${GREEN}${BOLD}Installation complete!${NC}"
    echo ""
    echo "  ${DIM}Restart your terminal or run:${NC}"
    echo "    ${CYAN}source $SHELL_RC${NC}"
    echo ""
    echo "  ${DIM}Then start with:${NC}"
    echo "    ${CYAN}tunnel${NC}"
    echo ""
}

main
