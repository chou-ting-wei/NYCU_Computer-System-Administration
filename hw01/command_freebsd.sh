# Post-installation
freebsd-update fetch install
freebsd-version

# Enable sudo
su -
pkg install sudo
visudo

# ---------- #
judge ALL=(ALL) NOPASSWD: ALL
# ---------- #

# Create group
sudo pw groupadd nycusa
sudo pw groupmod nycusa -m judge
groups judge

# Set your machine to Taiwan Standard Time 
sudo tzsetup Asia/Taipei

# Secure Shell
wget https://nasa.cs.nycu.edu.tw/sa/2024/nasakey.pub
ssh-copy-id -i nasakey.pub judge@127.0.0.1

# sudo service sshd enable
# sudo service sshd start
# sudo mkdir -p /home/judge/.ssh
# sudo fetch https://nasa.cs.nycu.edu.tw/sa/2024/nasakey.pub -o /home/judge/.ssh/authorized_keys
# ssh-keygen -l -f /home/judge/.ssh/authorized_keys

# Motd
sudo vi /etc/motd.template

# ---------- #
NYCU-SA-2024-88
# ---------- #

sudo service motd restart
cat /var/run/motd

# Configure pkg to use the CSIT mirror
sudo cp /etc/pkg/FreeBSD.conf /etc/pkg/FreeBSD.conf.backup
sudo vim /etc/pkg/FreeBSD.conf

# ---------- #
FreeBSD: {
  url: "http://pkg0.kwc.freebsd.org/${ABI}/quarterly",
  mirror_type: "srv",
  signature_type: "fingerprints",
  fingerprints: "/usr/share/keys/pkg",
  enabled: yes
}
# ---------- #

# echo 'FreeBSD: { enabled: no }' | sudo tee -a /usr/local/etc/pkg/repos/FreeBSD.conf
# echo 'CSIT: {
#   url: "http://pkg0.kwc.freebsd.org/${ABI}/quarterly",
#   mirror_type: "srv",
#   signature_type: "fingerprints",
#   fingerprints: "/usr/share/keys/pkg",
#   enabled: yes
# }' | sudo tee /usr/local/etc/pkg/repos/CSIT.conf

# Setup WireGuard
sudo pkg install -y wireguard-tools

sudo mkdir -p /usr/local/etc/wireguard
sudo vi /usr/local/etc/wireguard/wg0.conf

sudo wg-quick up wg0
ping -c 3 10.113.88.254 # ping -c 3 10.113.${ID}.254
