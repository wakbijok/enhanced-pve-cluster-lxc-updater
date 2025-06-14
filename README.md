# Proxmox Cluster LXC Updater

A comprehensive script for updating LXC containers across a Proxmox VE cluster. Combines the excellent user experience of tteck's community scripts with cluster-wide capabilities and safety features. I tested this on 3 nodes HCI Proxmox. You should adjust accordingly

## ✨ Features

### 🌐 Cluster-Wide Operations
- Updates LXC containers across **all accessible cluster nodes**
- Automatic SSH connectivity testing and node discovery
- Cross-node container management with proper error handling

### 🛡️ Safety & Validation
- **Dry-run mode** to preview changes without making modifications
- Interactive container selection with exclusion options
- Automatic template detection and skipping
- Smart container state management (auto-start/stop stopped containers)

### 📊 Advanced Monitoring
- **Real-time disk space monitoring** showing boot disk usage
- **Reboot detection** for containers requiring restarts
- Comprehensive progress reporting with colored output
- Per-node status tracking and error reporting

### 🎨 User Experience
- Beautiful ASCII art header and colored terminal output
- Interactive GUI using whiptail for container selection
- Multiple operation modes (interactive, automated, dry-run)
- Clear status messages and comprehensive summaries

## 📋 Prerequisites

### Required
- **Proxmox VE cluster** (tested on 3-node HCI setups)
- **Root access** on cluster nodes
- **SSH key authentication** configured between all cluster nodes

### Optional
- **whiptail** for interactive GUI (install with `apt install whiptail`)
  - Not required when using `--auto` mode

## 🚀 Installation

1. Clone this repository or download the script:
```bash
git clone https://github.com/wakbijok/enhanced-pve-cluster-lxc-updater.git
cd enhanced-pve-cluster-lxc-updater
```

2. Make the script executable:
```bash
chmod +x update-lxcs-cluster.sh
```

3. Ensure SSH keys are configured between cluster nodes:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t rsa -b 4096

# Copy to other cluster nodes
ssh-copy-id root@node2
ssh-copy-id root@node3
```

## 📖 Usage

### Basic Usage

```bash
# Interactive mode with GUI container selection
sudo ./update-lxcs-cluster.sh

# Dry-run to preview what would be updated
sudo ./update-lxcs-cluster.sh --dry-run

# Automated mode (no GUI, updates all running containers)
sudo ./update-lxcs-cluster.sh --auto

# Combined dry-run and auto mode
sudo ./update-lxcs-cluster.sh --dry-run --auto
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `--dry-run` | Show what would be done without making changes |
| `--auto` | Skip interactive menus, update all running containers |
| `--help` | Display usage information |

### Recommended Workflow

1. **First time**: Run dry-run to validate setup
```bash
sudo ./update-lxcs-cluster.sh --dry-run
```

2. **Interactive updates**: Use GUI to select specific containers
```bash
sudo ./update-lxcs-cluster.sh
```

3. **Automated updates**: For regular maintenance
```bash
sudo ./update-lxcs-cluster.sh --auto
```

## 🔧 Supported Operating Systems

The script automatically detects container OS types and uses appropriate package managers:

| OS Family | Package Manager | Update Commands |
|-----------|----------------|-----------------|
| Ubuntu/Debian/Devuan | `apt` | `apt-get update && apt-get dist-upgrade` |
| Fedora/Rocky/CentOS/Alma | `dnf/yum` | `dnf -y update && dnf -y upgrade` |
| Alpine Linux | `apk` | `apk -U upgrade` |
| Arch Linux | `pacman` | `pacman -Syyu --noconfirm` |
| openSUSE | `zypper` | `zypper ref && zypper --non-interactive dup` |

## 📊 Output Information

### Container Information Display
- **Container ID and hostname**
- **Node location** in cluster
- **Boot disk usage** (for supported OS types)
- **Update commands** being executed
- **Success/failure status**

### Summary Report
- Total containers found across cluster
- Successfully updated containers
- Failed updates with error details
- Skipped containers (templates, stopped, excluded)
- **Containers requiring reboot** after updates

## ⚠️ Important Notes

### SSH Configuration
- **Passwordless SSH** must be configured between all cluster nodes
- Test connectivity with: `ssh root@node-name "echo 'test successful'"`

### Container Behavior
- **Stopped containers** are automatically started, updated, then stopped
- **Templates** are automatically detected and skipped
- **Running containers** remain running after updates
- **Background shutdowns** are used for efficiency

### Safety Considerations
- Always run `--dry-run` first on new setups
- Monitor disk space warnings during updates
- Check reboot requirements in the summary
- Consider maintenance windows for production environments

## 🔍 Troubleshooting

### Common Issues

**SSH Connection Failed**
```bash
# Test SSH connectivity manually
ssh root@node-name "pct list"

# Check SSH key authentication
ssh -v root@node-name
```

**No Containers Found**
```bash
# Verify pct command works on remote nodes
ssh root@node-name "pct list"

# Check cluster status
pvecm status
```

**Permission Denied**
```bash
# Ensure script is run as root
sudo ./update-lxcs-cluster.sh

# Check file permissions
ls -la update-lxcs-cluster.sh
```

**Whiptail Not Found**
```bash
# Install whiptail
apt update && apt install whiptail

# Or use auto mode
sudo ./update-lxcs-cluster.sh --auto
```

## 🤝 Contributing

This script combines features from:
- [tteck's Proxmox VE Helper Scripts](https://github.com/community-scripts/ProxmoxVE) - Excellent single-node LXC management
- Custom cluster-wide enhancements for multi-node environments

Feel free to submit issues, feature requests, or pull requests to improve the script.

## 📝 License

This script is provided under the MIT License, maintaining compatibility with the original tteck scripts.

## 🙏 Acknowledgments

- **tteck (tteckster)** for the original excellent LXC update script and user experience design
- **Proxmox community** for the robust virtualization platform
- **Community-scripts project** for the foundation and inspiration

## 📞 Support

For issues or questions:
1. Check the troubleshooting section above
2. Run with `--dry-run` to validate setup
3. Test SSH connectivity manually
4. Review Proxmox cluster status with `pvecm status`

---

**⚡ Quick Start**: `sudo ./update-lxcs-cluster.sh --dry-run` to validate your setup!
