#!/usr/bin/env bash

# Enhanced Proxmox Cluster LXC Updater
# Combines tteck's excellent features with cluster-wide capabilities
# Usage: ./update-lxcs-cluster.sh [--dry-run] [--auto]

set -eEuo pipefail

# Parse command line arguments
DRY_RUN=false
AUTO_MODE=false
for arg in "$@"; do
    case $arg in
        --dry-run) DRY_RUN=true ;;
        --auto) AUTO_MODE=true ;;
        --help)
            echo "Usage: $0 [--dry-run] [--auto]"
            echo "  --dry-run: Show what would be done without making changes"
            echo "  --auto: Skip interactive menus (update all running containers)"
            exit 0
            ;;
    esac
done

# Colors and formatting
YW=$(echo "\033[33m")
BL=$(echo "\033[36m")
RD=$(echo "\033[01;31m")
GN=$(echo "\033[1;92m")
PU=$(echo "\033[0;35m")
CL=$(echo "\033[m")

function header_info() {
    clear
    cat <<"EOF"
   ________           __              __  __ __          __      __     
  / ____/ /_  _______/ /____  _____  / / / / _____ ____/ /___ _/ /____ 
 / /   / / / / / ___/ __/ _ \/ ___/ / / / / / __ \/ __  / __ `/ __/ _ \
/ /___/ / /_/ (__  ) /_/  __/ /    / /_/ / / /_/ / /_/ / /_/ / /_/  __/
\____/_/\__,_/____/\__/\___/_/     \____/_/ .___/\__,_/\__,_/\__/\___/ 
                                         /_/                           
EOF
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YW}                    DRY-RUN MODE - NO CHANGES WILL BE MADE${CL}"
    fi
    echo
}

function print_status() {
    echo -e "${BL}[Info]${CL} $1"
}

function print_success() {
    echo -e "${GN}[Success]${CL} $1"
}

function print_warning() {
    echo -e "${YW}[Warning]${CL} $1"
}

function print_error() {
    echo -e "${RD}[Error]${CL} $1"
}

function print_node() {
    echo -e "${PU}[Node]${CL} $1"
}

# Test SSH connectivity to a node
function test_ssh_connection() {
    local node=$1
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$node" "echo 'SSH test successful'" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Get disk info for a container
function get_disk_info() {
    local node=$1
    local container=$2
    local os=$3
    
    if [[ "$os" == "ubuntu" || "$os" == "debian" || "$os" == "fedora" ]]; then
        if [ "$node" = "$(hostname)" ]; then
            pct exec "$container" df /boot 2>/dev/null | awk 'NR==2{gsub("%","",$5); printf "%s %.1fG %.1fG %.1fG", $5, $3/1024/1024, $2/1024/1024, $4/1024/1024 }' || echo "N/A"
        else
            ssh "$node" "pct exec $container df /boot" 2>/dev/null | awk 'NR==2{gsub("%","",$5); printf "%s %.1fG %.1fG %.1fG", $5, $3/1024/1024, $2/1024/1024, $4/1024/1024 }' || echo "N/A"
        fi
    else
        echo "N/A"
    fi
}

# Check if container needs reboot
function needs_reboot() {
    local node=$1
    local container=$2
    
    if [ "$node" = "$(hostname)" ]; then
        pct exec "$container" -- [ -e "/var/run/reboot-required" ] 2>/dev/null
    else
        ssh "$node" "pct exec $container -- [ -e '/var/run/reboot-required' ]" 2>/dev/null
    fi
}

# Update a single container
function update_container() {
    local node=$1
    local container=$2
    local name=$3
    local os=$4
    local disk_info=$5
    
    header_info
    
    if [ "$disk_info" != "N/A" ]; then
        read -ra disk_info_array <<<"$disk_info"
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BL}[Info]${GN} [DRY-RUN] Would update ${BL}$container${CL} on ${PU}$node${CL} : ${GN}$name${CL} - ${YW}Boot Disk: ${disk_info_array[0]}% full [${disk_info_array[1]}/${disk_info_array[2]} used, ${disk_info_array[3]} free]${CL}\n"
        else
            echo -e "${BL}[Info]${GN} Updating ${BL}$container${CL} on ${PU}$node${CL} : ${GN}$name${CL} - ${YW}Boot Disk: ${disk_info_array[0]}% full [${disk_info_array[1]}/${disk_info_array[2]} used, ${disk_info_array[3]} free]${CL}\n"
        fi
    else
        if [ "$DRY_RUN" = true ]; then
            echo -e "${BL}[Info]${GN} [DRY-RUN] Would update ${BL}$container${CL} on ${PU}$node${CL} : ${GN}$name${CL} - ${YW}[No disk info for ${os}]${CL}\n"
        else
            echo -e "${BL}[Info]${GN} Updating ${BL}$container${CL} on ${PU}$node${CL} : ${GN}$name${CL} - ${YW}[No disk info for ${os}]${CL}\n"
        fi
    fi
    
    if [ "$DRY_RUN" = true ]; then
        case "$os" in
            alpine) echo "  Would run: apk -U upgrade" ;;
            archlinux) echo "  Would run: pacman -Syyu --noconfirm" ;;
            fedora | rocky | centos | alma) echo "  Would run: dnf -y update && dnf -y upgrade" ;;
            ubuntu | debian | devuan) echo "  Would run: apt-get update && apt-get -yq dist-upgrade" ;;
            opensuse) echo "  Would run: zypper ref && zypper --non-interactive dup" ;;
            *) echo "  Would run: Generic update commands" ;;
        esac
        return 0
    fi
    
    # Actual update commands
    if [ "$node" = "$(hostname)" ]; then
        case "$os" in
            alpine) pct exec "$container" -- ash -c "apk -U upgrade" ;;
            archlinux) pct exec "$container" -- bash -c "pacman -Syyu --noconfirm" ;;
            fedora | rocky | centos | alma) pct exec "$container" -- bash -c "dnf -y update && dnf -y upgrade" ;;
            ubuntu | debian | devuan) pct exec "$container" -- bash -c "apt-get update 2>/dev/null | grep 'packages.*upgraded'; apt list --upgradable && apt-get -yq dist-upgrade 2>&1; rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED" ;;
            opensuse) pct exec "$container" -- bash -c "zypper ref && zypper --non-interactive dup" ;;
        esac
    else
        case "$os" in
            alpine) ssh "$node" "pct exec $container -- ash -c 'apk -U upgrade'" ;;
            archlinux) ssh "$node" "pct exec $container -- bash -c 'pacman -Syyu --noconfirm'" ;;
            fedora | rocky | centos | alma) ssh "$node" "pct exec $container -- bash -c 'dnf -y update && dnf -y upgrade'" ;;
            ubuntu | debian | devuan) ssh "$node" "pct exec $container -- bash -c \"apt-get update 2>/dev/null | grep 'packages.*upgraded'; apt list --upgradable && apt-get -yq dist-upgrade 2>&1; rm -rf /usr/lib/python3.*/EXTERNALLY-MANAGED\"" ;;
            opensuse) ssh "$node" "pct exec $container -- bash -c 'zypper ref && zypper --non-interactive dup'" ;;
        esac
    fi
}

# Get container status
function get_container_status() {
    local node=$1
    local container=$2
    
    if [ "$node" = "$(hostname)" ]; then
        pct status "$container"
    else
        ssh "$node" "pct status $container"
    fi
}

# Get container config
function get_container_config() {
    local node=$1
    local container=$2
    
    if [ "$node" = "$(hostname)" ]; then
        pct config "$container"
    else
        ssh "$node" "pct config $container"
    fi
}

# Start container
function start_container() {
    local node=$1
    local container=$2
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BL}[Info]${GN} [DRY-RUN] Would start ${BL}$container${CL} on ${PU}$node${CL}"
        return 0
    fi
    
    echo -e "${BL}[Info]${GN} Starting ${BL}$container${CL} on ${PU}$node${CL}"
    if [ "$node" = "$(hostname)" ]; then
        pct start "$container"
    else
        ssh "$node" "pct start $container"
    fi
    echo -e "${BL}[Info]${GN} Waiting for ${BL}$container${CL} to start${CL}"
    sleep 5
}

# Stop container
function stop_container() {
    local node=$1
    local container=$2
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${BL}[Info]${GN} [DRY-RUN] Would shutdown ${BL}$container${CL} on ${PU}$node${CL}"
        return 0
    fi
    
    echo -e "${BL}[Info]${GN} Shutting down ${BL}$container${CL} on ${PU}$node${CL}"
    if [ "$node" = "$(hostname)" ]; then
        pct shutdown "$container" &
    else
        ssh "$node" "pct shutdown $container" &
    fi
}

# Main function
function main() {
    header_info
    
    if [ "$DRY_RUN" = false ] && [ "$AUTO_MODE" = false ]; then
        if ! whiptail --backtitle "Proxmox VE Helper Scripts" --title "Proxmox VE Cluster LXC Updater" --yesno "This will update LXC containers across your cluster. Proceed?" 10 58; then
            exit 0
        fi
    fi
    
    print_status "Discovering cluster nodes..."
    
    # Get cluster nodes
    local current_node=$(hostname)
    local nodes
    if command -v pvesh >/dev/null 2>&1; then
        nodes=$(pvesh get /nodes --output-format json 2>/dev/null | jq -r '.[].node' 2>/dev/null || pvecm nodes 2>/dev/null | awk 'NR>1 {print $3}' | grep -v "$current_node" || echo "")
    else
        nodes=$(pvecm nodes 2>/dev/null | awk 'NR>1 {print $3}' | grep -v "$current_node" || echo "")
    fi
    
    local all_nodes="$current_node $nodes"
    print_status "Cluster nodes: $all_nodes"
    
    # Test SSH connectivity
    local accessible_nodes=()
    for node in $all_nodes; do
        if [ "$node" = "$current_node" ]; then
            accessible_nodes+=("$node")
            print_success "Local node: $node"
        elif test_ssh_connection "$node"; then
            accessible_nodes+=("$node")
            print_success "SSH accessible: $node"
        else
            print_error "Cannot connect to node: $node"
        fi
    done
    
    if [ ${#accessible_nodes[@]} -eq 0 ]; then
        print_error "No accessible nodes found!"
        exit 1
    fi
    
    echo
    
    # Collect all containers from all nodes
    local all_containers=()
    local exclude_menu=()
    local msg_max_length=0
    
    for node in "${accessible_nodes[@]}"; do
        print_status "Scanning containers on $node..."
        
        local containers
        if [ "$node" = "$current_node" ]; then
            containers=$(pct list | awk 'NR>1 {print $1 ":" $2 ":" $3}' 2>/dev/null || echo "")
        else
            containers=$(ssh "$node" "pct list" | awk 'NR>1 {print $1 ":" $2 ":" $3}' 2>/dev/null || echo "")
        fi
        
        while IFS=: read -r vmid status name; do
            if [ -n "$vmid" ]; then
                local display_item="$vmid ($name) on $node"
                all_containers+=("$node:$vmid:$status:$name")
                
                local offset=2
                ((${#display_item} + offset > msg_max_length)) && msg_max_length=${#display_item}+offset
                exclude_menu+=("$node:$vmid" "$display_item" "OFF")
            fi
        done <<< "$containers"
    done
    
    if [ ${#all_containers[@]} -eq 0 ]; then
        print_warning "No containers found on any accessible nodes!"
        exit 0
    fi
    
    # Container selection
    local excluded_containers=""
    if [ "$AUTO_MODE" = false ]; then
        excluded_containers=$(whiptail --backtitle "Proxmox VE Helper Scripts" --title "Containers in Cluster" --checklist "\nSelect containers to skip from updates:\n" 20 $((msg_max_length + 25)) 10 "${exclude_menu[@]}" 3>&1 1>&2 2>&3 | tr -d '"') || exit 0
    fi
    
    # Process containers
    local updated_containers=()
    local failed_containers=()
    local skipped_containers=()
    local containers_needing_reboot=()
    local started_containers=()
    
    for container_info in "${all_containers[@]}"; do
        IFS=: read -r node vmid status name <<< "$container_info"
        
        # Check if container should be excluded
        if [[ " $excluded_containers " =~ " $node:$vmid " ]]; then
            header_info
            echo -e "${BL}[Info]${GN} Skipping ${BL}$vmid${CL} ($name) on ${PU}$node${CL}"
            skipped_containers+=("$node:$vmid")
            sleep 1
            continue
        fi
        
        # Get container configuration
        local config
        config=$(get_container_config "$node" "$vmid")
        local template=$(echo "$config" | grep -q "template:" && echo "true" || echo "false")
        local os=$(echo "$config" | awk '/^ostype/ {print $2}')
        local hostname=$(echo "$config" | awk '/^hostname/ {print $2}' || echo "$name")
        
        # Skip templates
        if [ "$template" = "true" ]; then
            print_warning "Skipping template $vmid on $node"
            skipped_containers+=("$node:$vmid")
            continue
        fi
        
        local current_status=$(get_container_status "$node" "$vmid")
        local was_stopped=false
        
        # Handle stopped containers
        if [[ "$current_status" == "status: stopped" ]]; then
            start_container "$node" "$vmid"
            was_stopped=true
            started_containers+=("$node:$vmid")
        elif [[ "$current_status" != "status: running" ]]; then
            print_warning "Container $vmid on $node is not in a valid state: $current_status"
            skipped_containers+=("$node:$vmid")
            continue
        fi
        
        # Get disk info
        local disk_info=$(get_disk_info "$node" "$vmid" "$os")
        
        # Update container
        if update_container "$node" "$vmid" "$hostname" "$os" "$disk_info"; then
            if [ "$DRY_RUN" = true ]; then
                print_success "[DRY-RUN] Would successfully update $vmid on $node"
            else
                print_success "Successfully updated $vmid on $node"
            fi
            updated_containers+=("$node:$vmid")
            
            # Check if reboot is needed
            if [ "$DRY_RUN" = false ] && needs_reboot "$node" "$vmid"; then
                containers_needing_reboot+=("$vmid ($hostname) on $node")
            fi
        else
            if [ "$DRY_RUN" = true ]; then
                print_error "[DRY-RUN] Would fail to update $vmid on $node"
            else
                print_error "Failed to update $vmid on $node"
            fi
            failed_containers+=("$node:$vmid")
        fi
        
        # Stop container if we started it
        if [ "$was_stopped" = true ]; then
            stop_container "$node" "$vmid"
        fi
    done
    
    # Wait for background shutdowns
    if [ "$DRY_RUN" = false ]; then
        wait
    fi
    
    # Final summary
    header_info
    if [ "$DRY_RUN" = true ]; then
        echo -e "${GN}Dry-run complete! Here's what would happen:${CL}\n"
    else
        echo -e "${GN}The process is complete, and the containers have been successfully updated.${CL}\n"
    fi
    
    echo "Total containers processed: ${#all_containers[@]}"
    if [ "$DRY_RUN" = true ]; then
        echo "Would be updated: ${#updated_containers[@]}"
        echo "Would fail: ${#failed_containers[@]}"
        echo "Would be skipped: ${#skipped_containers[@]}"
    else
        echo "Successfully updated: ${#updated_containers[@]}"
        echo "Failed: ${#failed_containers[@]}"
        echo "Skipped: ${#skipped_containers[@]}"
    fi
    echo
    
    if [ ${#containers_needing_reboot[@]} -gt 0 ]; then
        echo -e "${RD}The following containers require a reboot:${CL}"
        for container_name in "${containers_needing_reboot[@]}"; do
            echo "  $container_name"
        done
        echo
    fi
    
    if [ "$DRY_RUN" = true ]; then
        echo -e "${YW}Run without --dry-run to perform actual updates.${CL}"
    fi
}

# Check requirements
if [ "$EUID" -ne 0 ]; then
    print_error "This script must be run as root"
    exit 1
fi

if ! command -v pct >/dev/null 2>&1; then
    print_error "pct command not found. Run this on a Proxmox node."
    exit 1
fi

if [ "$AUTO_MODE" = false ] && ! command -v whiptail >/dev/null 2>&1; then
    print_error "whiptail not found. Install it or use --auto flag."
    exit 1
fi

# Run main function
main
