#!/bin/bash

# Error handling function
check_error() {
    if [ $? -ne 0 ]; then
        echo "Error: $1"
        exit 1
    fi
}

# Network cleanup function
cleanup_network() {
    echo "Cleaning up network configuration..."

    # Kill all running dnsmasq processes
    sudo pkill dnsmasq

    # Remove any leftover network interface
    sudo ip link set virbr0 down 2>/dev/null
    sudo brctl delbr virbr0 2>/dev/null

    # Remove old network configurations
    sudo rm -f /var/lib/libvirt/dnsmasq/default.conf
    sudo rm -f /var/lib/libvirt/dnsmasq/default.status

    # Stop and remove the old network
    sudo virsh net-destroy default >/dev/null 2>&1
    sudo virsh net-undefine default >/dev/null 2>&1

    # Wait a moment to ensure all processes have stopped
    sleep 2
}

# Update system and install required packages
echo "Updating system and installing required packages..."
sudo apt update
sudo apt install -y qemu-kvm libvirt-daemon-system virtinst bridge-utils virt-viewer dnsmasq
check_error "Failed to install required packages"

# Enable and start libvirt services
echo "Enabling virtualization services..."
sudo systemctl enable --now libvirtd
sudo systemctl start libvirtd
check_error "Failed to start libvirtd service"

# Cleanup old network configuration
cleanup_network

# Setup virtual network configuration
echo "Setting up virtual network..."
cat << EOF > default-network.xml
<network>
  <name>default</name>
  <forward mode='nat'/>
  <bridge name='virbr0' stp='on' delay='0'/>
  <ip address='192.168.122.1' netmask='255.255.255.0'>
    <dhcp>
      <range start='192.168.122.2' end='192.168.122.254'/>
    </dhcp>
  </ip>
</network>
EOF

# Define and start the new network
sudo virsh net-define default-network.xml
check_error "Failed to define network"
sudo virsh net-start default
check_error "Failed to start network"
sudo virsh net-autostart default
check_error "Failed to autostart network"

# Verify network configuration
echo "Verifying network configuration..."
if ! sudo virsh net-list --all | grep -q "default"; then
    echo "Error: Network configuration failed"
    exit 1
fi

# Create directory for VM
echo "Creating VM directory..."
sudo mkdir -p /var/lib/libvirt/images
cd /var/lib/libvirt/images || exit

# Download Windows Server 2012 ISO
echo "Downloading Windows Server 2012 ISO..."
if [ ! -f /var/lib/libvirt/images/windows_server_2012.iso ]; then
    # sudo wget -O /var/lib/libvirt/images/windows_server_2022.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US"
    sudo wget -O /var/lib/libvirt/images/windows_server_2012.iso "https://go.microsoft.com/fwlink/p/?LinkID=2195443&clcid=0x409&culture=en-us&country=US"
	check_error "Failed to download Windows Server ISO"
fi

# Set permissions for ISO
echo "Setting correct permissions..."
sudo chown libvirt-qemu:libvirt-qemu /var/lib/libvirt/images/windows_server_2012.iso
check_error "Failed to set ISO permissions"

# Cleanup old VM if exists
echo "Cleaning up old VM if exists..."
sudo virsh destroy windows_server_2012 >/dev/null 2>&1
sudo virsh undefine windows_server_2012 >/dev/null 2>&1

# Create virtual disk (set to 2TB)
echo "Creating virtual disk..."
sudo qemu-img create -f qcow2 windows_server_2012.qcow2 400G
check_error "Failed to create virtual disk"
sudo chown libvirt-qemu:libvirt-qemu windows_server_2012.qcow2
check_error "Failed to set disk permissions"

# Create and start the VM
echo "Creating and starting VM..."
sudo virt-install \
  --name windows_server_2012 \
  --ram 45000 \
  --boot useserial=on\
  --disk path=/var/lib/libvirt/images/windows_server_2012.qcow2 \
  --vcpus 12 \
  --noautoconsole \
  --os-variant win2k22 \
  --network network=default \
  --graphics vnc,listen=0.0.0.0,port=5922 \
  --cdrom /var/lib/libvirt/images/windows_server_2012.iso \
  --boot cdrom,hd \
  --osinfo win2k22

# If we reached here, the VM has been created successfully
echo "VM created successfully!"
echo "Use these commands to manage your VM:"
echo "Start VM:   sudo virsh start windows_server_2012"
echo "Stop VM:    sudo virsh shutdown windows_server_2012"
echo "Force Stop: sudo virsh destroy windows_server_2012"
echo "Delete VM:  sudo virsh undefine windows_server_2012 --remove-all-storage"
echo ""
echo "To connect via VNC:"
echo "1. Create SSH tunnel: ssh -L 5900:localhost:5900 username@vps-ip"
echo "2. Connect VNC viewer to: localhost:5900"

# Show VM status
echo -e "\nCurrent VM Status:"
sudo virsh list --all
