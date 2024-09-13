ssh -p 2020 twchou@140.113.121.154

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
ssh-keygen -l -f /home/judge/.ssh/authorized_keys

# Motd
sudo nano /etc/update-motd.d/99-motd

# ---------- #
#!/bin/sh
echo "NYCU-SA-2024-112550013"
# ---------- #

sudo chmod +x /etc/update-motd.d/50-motd
run-parts --lsbsysinit /etc/update-motd.d

# Package Repository Mirror
# sudo cp /etc/apt/sources.list.d/ubuntu.sources /etc/apt/sources.list.d/ubuntu.sources.backup
# sudo nano /etc/apt/sources.list.d/ubuntu.sources

sudo nano /etc/apt/sources.list
# ---------- #
deb http://ubuntu.cs.nycu.edu.tw/ubuntu/ noble main 
deb-src http://ubuntu.cs.nycu.edu.tw/ubuntu/ noble main 
# ---------- #
sudo apt update

# Setup WireGuard
sudo apt install wireguard
sudo nano /etc/wireguard/wg0.conf

sudo wg-quick up wg0
ping -c 3 10.113.88.254 # ping -c 3 10.113.${ID}.254
sudo systemctl enable wg-quick@wg0
