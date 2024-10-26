# HW 3-1: File server (24%)

# Create Users
# Create sysadm with SSH access
sudo pw groupadd sftp-users
sudo pw useradd sysadm -m -s /bin/sh -G sftp-users
sudo pw useradd sftp-u1 -m -s /usr/sbin/nologin -G sftp-users
sudo pw useradd sftp-u2 -m -s /usr/sbin/nologin -G sftp-users
sudo pw useradd anonymous -m -s /usr/sbin/nologin

# Create Directories
sudo mkdir -p /home/sftp/public
sudo mkdir -p /home/sftp/hidden/treasure
sudo touch /home/sftp/hidden/treasure/secret

sudo ln -s /home/sftp/public /home/sysadm/public
sudo ln -s /home/sftp/hidden /home/sysadm/hidden

