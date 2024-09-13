# Your machine should boot using UEFI
ls /sys/firmware/efi

# Set hostname to sa2024-${ID}
sudo hostnamectl set-hostname sa2024-88

# Create user
sudo adduser --disabled-password judge
sudo usermod -aG sudo judge
sudo chsh -s /bin/sh judge
echo "judge ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/judge

# Create group
sudo addgroup nycusa
sudo usermod -aG nycusa judge 

# Set your machine to Taiwan Standard Time 
sudo vi /etc/systemd/timesyncd.conf

# ---------- #
[Time]
NTP=tock.stdtime.gov.tw watch.stdtime.gov.tw
FallbackNTP=ntp.ubuntu.com
# ---------- #

sudo systemctl restart systemd-timesyncd
timedatectl status

# Secure Shell
sudo service ssh start
sudo systemctl enable ssh

sudo mkdir -p /home/judge/.ssh
sudo wget -O /home/judge/.ssh/authorized_keys https://nasa.cs.nycu.edu.tw/sa/2024/nasakey.pub
sudo ssh-keygen -l -f /home/judge/.ssh/authorized_keys

# Motd
sudo vi /etc/update-motd.d/99-motd

# ---------- #
#!/bin/sh
echo "NYCU-SA-2024-88"
# ---------- #

sudo chmod +x /etc/update-motd.d/99-motd
run-parts --lsbsysinit /etc/update-motd.d

# Package Repository Mirror
sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.backup
sudo vi /etc/apt/sources.list.d/ubuntu.sources
# ---------- #
Types: deb
URIs: http://ubuntu.cs.nycu.edu.tw/ubuntu/
Suites: noble noble-updates noble-backports
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg

Types: deb
URIs: http://security.ubuntu.com/ubuntu/
Suites: noble-security
Components: main restricted universe multiverse
Signed-By: /usr/share/keyrings/ubuntu-archive-keyring.gpg
# ---------- #
sudo apt update

# sudo vi /etc/apt/sources.list
# # ---------- #
# deb http://ubuntu.cs.nycu.edu.tw/ubuntu/ noble main 
# deb-src http://ubuntu.cs.nycu.edu.tw/ubuntu/ noble main 
# # ---------- #
# sudo apt update

# Setup WireGuard
sudo apt install wireguard
sudo vi /etc/wireguard/wg0.conf

sudo wg-quick up wg0
ping -c 3 10.113.88.254 # ping -c 3 10.113.${ID}.254
sudo systemctl enable wg-quick@wg0
