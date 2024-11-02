# ------------------------------
# HW 3-1: File server (24%)
# ------------------------------

# Create Users
# Create sysadm with SSH access
sudo adduser sysadm
sudo adduser sftp-u1 --shell /usr/sbin/nologin
sudo adduser sftp-u2 --shell /usr/sbin/nologin
sudo adduser anonymous --shell /usr/sbin/nologin

# Set Up Groups and Add Users
sudo groupadd sftp-users
sudo usermod -aG sftp-users sysadm
sudo usermod -aG sftp-users sftp-u1
sudo usermod -aG sftp-users sftp-u2

# Create Directories
sudo mkdir -p /home/sftp/public
sudo mkdir -p /home/sftp/hidden/treasure
sudo touch /home/sftp/hidden/treasure/secret

sudo ln -s /home/sftp/public /home/sysadm/public
sudo ln -s /home/sftp/hidden /home/sysadm/hidden

# Set Ownership and Permissions
# /home/sftp
sudo chown root:root /home/sftp
sudo chmod 755 /home/sftp
# /home/sftp/public
sudo chown root:sftp-users /home/sftp/public
sudo chmod 2775 /home/sftp/public    # Set setgid bit
sudo chmod +t /home/sftp/public      # Set sticky bit
# /home/sftp/hidden
sudo chown sysadm:sftp-users /home/sftp/hidden
sudo chmod 771 /home/sftp/hidden
# /home/sftp/hidden/treasure
sudo chown sysadm:sftp-users /home/sftp/hidden/treasure
sudo chmod 755 /home/sftp/hidden/treasure
# /home/sftp/hidden/treasure/secret
sudo chown sysadm:sftp-users /home/sftp/hidden/treasure/secret
sudo chmod 644 /home/sftp/hidden/treasure/secret

sudo mkdir -p /home/sftp/home/{sftp-u1,sftp-u2,anonymous}
for user in sftp-u1 sftp-u2 anonymous; do
    sudo chown $user:$user /home/sftp/home/$user
    sudo chmod 700 /home/sftp/home/$user
done

# Configure SSH Key Authentication
JUDGE_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+i+HeIdzPSCHcZfGPAieFc5HsdLUCz7ebYDwv/lpMZ judge@sa-2024"
USER_PUB_KEY="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQCeQidmU94kze7JsoUQ0hcXyQmGEQNoaCrmdVSK4rboGFO1y+4MPiFP4aYaPy3Y7SxwYzQciqFNDCqXUFmxaTbA2uqNhmJ0pJMTB3SW5uzhcvhNmQUk8IPq1STgA1kbOWc9+CMQebwWPMMD7Pn+3OuRKKU0VlN53w68GvIVya2HfeBa53AQaLeScw2DHVQpJbojOpW1LaOYACXRQRrffKyYEkMjnAJctGK54DWHhMdLHIkhd2+A0jXqUKeNf7a91Su9MgQ2QtkpGAdlUgFXo0MBt2u13E5XaGDUAB9XL4nTVQ8cKbB+tHqzjQ87ICvl3oD9x2EhMhKy7m117ugN2nSL4hk/P8NpMrphH1yIlfSDSOeWkqzu0hrSuF87H3aEFEVs8SCo3Ik3X3epZ4Sr/mpGRTIVuECGshwG+hPd0z3+h0OoM94907BbQQKNV+an/hB3QGHpvp7O08nwdcsLOwuuC1cJPUOfarliAvSeRRrB4DphoRziIEMj9UThlD8UzA5YC8GJXMe2ke+UkPP2Z0lKsZobLYZKHcp2OuSVG8gxh6KLmxR/H++UDXinBqgyyxM5PniO+Mk2/26xBT7RFo8GcyS0O1Zw4Tb8M9l28ltHEQMRspir+bCn7gsbAnq8oEp+LlsjFKKEjHe4Cq8/TogZ30YD2ShphXoP+kA9+QJvYw== twchou@twchous-MacBook-Air.local"
# For sysadm
sudo mkdir -p /home/sysadm/.ssh
sudo chmod 700 /home/sysadm/.ssh
echo "$JUDGE_PUB_KEY" | sudo tee -a /home/sysadm/.ssh/authorized_keys
echo "$USER_PUB_KEY" | sudo tee -a /home/sysadm/.ssh/authorized_keys
sudo chmod 600 /home/sysadm/.ssh/authorized_keys
sudo chown -R sysadm:sysadm /home/sysadm/.ssh
# For chrooted users
for user in sftp-u1 sftp-u2 anonymous; do
    sudo mkdir -p /home/sftp/home/$user/.ssh
    sudo chmod 700 /home/sftp/home/$user/.ssh
    echo "$JUDGE_PUB_KEY" | sudo tee -a /home/sftp/home/$user/.ssh/authorized_keys
    echo "$USER_PUB_KEY" | sudo tee -a /home/sftp/home/$user/.ssh/authorized_keys
    sudo chmod 600 /home/sftp/home/$user/.ssh/authorized_keys
    sudo chown -R $user:$user /home/sftp/home/$user/.ssh
done

# Update Users' Home Directories
sudo usermod -d /home/sftp/home/sftp-u1 sftp-u1
sudo usermod -d /home/sftp/home/sftp-u2 sftp-u2
sudo usermod -d /home/sftp/home/anonymous anonymous

# Configure SSHD for SFTP and Chroot
sudo vim /etc/ssh/sshd_config
# ----------
Subsystem sftp internal-sftp

Match User sftp-u1,sftp-u2,anonymous
    ChrootDirectory /home/sftp
    ForceCommand internal-sftp -u 027
    PermitTTY no
    AllowTcpForwarding no
    X11Forwarding no
# ----------
sudo systemctl restart sshd

# ------------------------------
# HW 3-2: SFTP auditing with RC (22%)
# ------------------------------

# Configure SSHD to Log SFTP Actions
sudo vim /etc/ssh/sshd_config
# ----------
Subsystem sftp internal-sftp -l VERBOSE -f LOCAL7

Match User sftp-u1,sftp-u2,anonymous
    ChrootDirectory /home/sftp
    ForceCommand internal-sftp -u 027 -l VERBOSE -f LOCAL7
    PermitTTY no
    AllowTcpForwarding no
    X11Forwarding no
# ----------
sudo systemctl restart sshd

sudo mkdir /home/sftp/dev
sudo chown root:root /home/sftp/dev
sudo chmod 755 /home/sftp/dev
sudo touch /home/sftp/dev/log
sudo mount --bind /run/systemd/journal/dev-log /home/sftp/dev/log
ls -l /home/sftp/dev/log

sudo vim /etc/rsyslog.d/40-sftp.conf
# ----------
$AddUnixListenSocket /home/sftp/dev/log

LOCAL7.* /var/log/sftp.log
# ----------
sudo systemctl restart rsyslog

sudo touch /var/log/sftp.log
sudo chown root:adm /var/log/sftp.log
sudo chmod 666 /var/log/sftp.log

sudo tail -f /var/log/sftp.log

sudo vim /etc/systemd/system/bind-log.service
sudo systemctl enable bind-log.service

sudo vim /usr/local/bin/sftp_watchd

sudo chmod +x /usr/local/bin/sftp_watchd
sudo touch /var/log/sftp_watchd.log
sudo chown root:adm /var/log/sftp_watchd.log
sudo chmod 666 /var/log/sftp_watchd.log
sudo mkdir -p /home/sftp/hidden/.violated/
sudo chown root:sftp-users /home/sftp/hidden/.violated/
sudo chmod 775 /home/sftp/hidden/.violated/

# Create the RC Script for sftp_watchd Service
sudo vim /etc/init.d/sftp_watchd

sudo chmod +x /etc/init.d/sftp_watchd
sudo update-rc.d sftp_watchd defaults

sudo vim /etc/systemd/system/sftp_watchd.service
sudo systemctl enable sftp_watchd.service
sudo systemctl daemon-reload

sudo service sftp_watchd start
sudo service sftp_watchd status
sudo service sftp_watchd stop
sudo service sftp_watchd restart

sudo tail -f /var/log/sftp_watchd.log

# ------------------------------
# HW 3-3: ZFS & Backup (54%)
# ------------------------------

sudo apt update
sudo apt install zfsutils-linux
sudo apt install gdisk

# Configure the New Disk
# Choose “VDI (VirtualBox Disk Image)” as the disk type.

lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL

# Partitioning with GPT
sudo gdisk /dev/sdb
sudo gdisk /dev/sdc
sudo gdisk /dev/sdd
sudo gdisk /dev/sde

# Create a New GPT Partition Table:
# Command: o (creates a new empty GUID partition table)
# Prompt: Confirm by typing y

# Create a New Partition:
# Command: n (add a new partition)
# Partition Number: Press Enter to accept default (1)
# First Sector: Press Enter to accept default
# Last Sector: Press Enter to use the entire disk
# Hex Code or GUID: bf00 (Solaris root)

# Set the Partition Label:
# Command: c (change the partition's name)
# Partition Number: 1
# Name: mypool-1 (for /dev/sdb), mypool-2 (for /dev/sdc),
#       mypool-3 (for /dev/sdd), mypool-4 (for /dev/sde).

# Write Changes and Exit:
# Command: w (write table to disk and exit)
# Prompt: Confirm by typing y

lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,LABEL
sudo blkid

sudo zpool create mypool \
  mirror /dev/disk/by-partlabel/mypool-1 /dev/disk/by-partlabel/mypool-2 \
  mirror /dev/disk/by-partlabel/mypool-3 /dev/disk/by-partlabel/mypool-4
sudo zpool status

sudo zfs set mountpoint=/home/sftp mypool
sudo zfs get mountpoint mypool

sudo systemctl enable zfs-import-cache.service
sudo systemctl enable zfs-mount.service
sudo systemctl enable zfs-import.target
sudo systemctl enable zfs.target

sudo reboot
df -h | grep sftp

# Create ZFS Datasets
sudo zfs create mypool/public
sudo zfs create mypool/hidden

sudo zfs set compression=lz4 mypool
sudo zfs set atime=off mypool
sudo zfs get compression,atime mypool

# Automatic Snapshot Script: zfsbak
sudo vim /usr/local/bin/zfsbak

sudo chmod +x /usr/local/bin/zfsbak
