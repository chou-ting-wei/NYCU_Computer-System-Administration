# HW 3-1: File server (24%)

# Create Users
# Create sysadm with SSH access
sudo adduser sysadm
# Create sftp-u1 and sftp-u2 without SSH access
sudo adduser sftp-u1 --shell /usr/sbin/nologin
sudo adduser sftp-u2 --shell /usr/sbin/nologin
# Create anonymous without SSH access
sudo adduser anonymous --shell /usr/sbin/nologin


# Set Up Groups and Add Users
# Create sftp-users group
sudo groupadd sftp-users
# Add users to sftp-users group
sudo usermod -aG sftp-users sysadm
sudo usermod -aG sftp-users sftp-u1
sudo usermod -aG sftp-users sftp-u2

# Create Directories
# Create the base SFTP directory and subdirectories
sudo mkdir -p /home/sftp/public
sudo mkdir -p /home/sftp/hidden/treasure
# Create the "secret" file
sudo touch /home/sftp/hidden/treasure/secret

# Create Symlinks in sysadm's Home Directory
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

# Create Home Directories for Chrooted Users
sudo mkdir -p /home/sftp/home/{sftp-u1,sftp-u2,anonymous}

# Set ownership and permissions
for user in sftp-u1 sftp-u2 anonymous; do
    sudo chown $user:$user /home/sftp/home/$user
    sudo chmod 700 /home/sftp/home/$user
done

# Configure SSH Key Authentication
JUDGE_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+i+HeIdzPSCHcZfGPAieFc5HsdLUCz7ebYDwv/lpMZ judge@sa-2024"
USER_PUB_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGYHIVa6+a/PT6tTlN+S5dvSiqj9am5NitZ05yTzMNIp chou.ting.wei@twchous-MacBook-Pro"
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

# Set Default ACLs and Permissions
# Remove 'others' permissions on new files in /home/sftp/public
# sudo setfacl -d -m o::0 /home/sftp/public
# Ensure anonymous has read-only access
# Set permissions for public directory
sudo chmod -R o-w /home/sftp/public
# Set permissions for hidden directory
sudo chmod -R o-w /home/sftp/hidden
