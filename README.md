# libvirt-windows-vm-installer
A bash script to automate the setup of Windows VMs on Linux using libvirt, including network configuration, ISO download, and VM provisioning with custom resources.

## [ Installation ]
Compatible with 3 linux distros:
- Ubuntu
- CentOS
- AlmaLinux

```bash
git clone https://github.com/aritlh/libvirt-windows-vm-installer
cd libvirt-windows-vm-installer
chmod +x *
./<your_linux_distro>.sh
```

## [ Troubleshooting ]
If you find an error with DNS, the problem might be with the `dnsmasq` version. Downgrade your `dnsmasq` version.

For ubuntu:
```
sudo apt install dnsmasq-base=2.86-1.1
```
