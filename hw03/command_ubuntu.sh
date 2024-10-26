# HW 3-1: File server (24%)

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

# Set Permissions for Directories
# Set permissions for public directory
# sudo chmod -R o-w /home/sftp/public
# Set permissions for hidden directory
# sudo chmod -R o-w /home/sftp/hidden


# HW 3-2: SFTP auditing with RC (22%)
# Configure SSHD to Log SFTP Actions
sudo vim /etc/ssh/sshd_config
# ----------
Subsystem sftp internal-sftp -l VERBOSE

Match User sftp-u1,sftp-u2,anonymous
    ChrootDirectory /home/sftp
    ForceCommand internal-sftp -u 027
    PermitTTY no
    AllowTcpForwarding no
    X11Forwarding no
# ----------
sudo systemctl restart sshd

sudo mkdir /home/sftp/dev
sudo chown root:root /home/sftp/dev
sudo chmod 777 /home/sftp/dev
sudo touch /home/sftp/dev/log
sudo mount --bind /run/systemd/journal/dev-log /home/sftp/dev/log

mount | grep /home/sftp/dev/log


# sudo vim /etc/fstab
# # ----------
# /run/systemd/journal/dev-log /home/sftp/dev/log none bind,nofail,x-systemd.requires=sshd.service
# # ----------

# sudo vim /etc/rsyslog.d/40-sftp.conf
# # ----------
# # SFTP log source
# $ModLoad imuxsock  # For Unix sockets like /dev/log
# $ModLoad imfile    # For reading file sources

# # Input source for the custom SFTP log
# input(type="imuxsock" Socket="/home/sftp/dev/log")

# # SFTP-specific filter and logging
# if $programname == 'internal-sftp' then /var/log/sftp.log
# & stop
# # ----------
# sudo systemctl restart rsyslog

sudo apt update
sudo apt install syslog-ng

sudo vim /etc/syslog-ng/syslog-ng.conf
# ----------
source s_src {
  internal();
  file("/proc/kmsg");
  unix-dgram("/dev/log");
  unix-dgram("/home/sftp/dev/log");
};

#sftp configuration
destination d_sftp { file("/var/log/sftp.log"); };
filter f_sftp { program("internal-sftp"); };
log { source(src); filter(f_sftp); destination(d_sftp); };
# ----------
sudo systemctl restart syslog-ng


sudo touch /var/log/sftp.log
sudo chown root:adm /var/log/sftp.log
sudo chmod 740 /var/log/sftp.log

sudo tail -f /var/log/sftp.log
# sudo tail -f /var/log/auth.log



sudo vim /usr/local/bin/sftp_watchd
# ----------
#!/usr/bin/env python3

import time
import os
import re
import shutil
import logging
import pwd
import sys

# Configure logging
logging.basicConfig(
    filename='/var/log/sftp_watchd.log',
    level=logging.INFO,
    format='%(asctime)s %(hostname)s sftp_watchd[%(process)d]: %(message)s',
    datefmt='%b %d %H:%M:%S'
)
# Add hostname to logging
logging.Formatter.converter = time.gmtime
logging.Formatter.default_msec_format = '%s.%03d'

# Get the hostname
hostname = os.uname()[1]

# Path to monitor
sftp_log = '/var/log/sftp.log'

# Directory to move violated files
violated_dir = '/home/sftp/hidden/.violated/'

# Ensure the violated directory exists
if not os.path.exists(violated_dir):
    os.makedirs(violated_dir)

# Function to check if a file is executable
def is_executable(file_path):
    try:
        # Use the 'file' command to check the file type
        import subprocess
        result = subprocess.run(['file', '--mime-type', '-b', file_path], stdout=subprocess.PIPE)
        mime_type = result.stdout.decode().strip()
        return 'application/x-executable' in mime_type or 'application/x-dosexec' in mime_type
    except Exception as e:
        return False

# Function to get the username from UID
def get_username(uid):
    try:
        return pwd.getpwuid(uid).pw_name
    except KeyError:
        return str(uid)

# Monitor the sftp.log file
def monitor_log():
    with open(sftp_log, 'r') as f:
        # Move to the end of the file
        f.seek(0, os.SEEK_END)
        while True:
            line = f.readline()
            if not line:
                time.sleep(0.1)
                continue
            # Check for 'open' operation indicating file upload
            match = re.search(r'open "(.*?)" flags WRITE,CREATE', line)
            if match:
                file_path = match.group(1)
                # Since the paths are relative to the chroot, adjust the path
                full_path = os.path.join('/home/sftp', file_path.lstrip('/'))
                if os.path.exists(full_path):
                    if is_executable(full_path):
                        uploader_match = re.search(r'for local user ([\w-]+)', line)
                        if uploader_match:
                            uploader = uploader_match.group(1)
                        else:
                            uploader = 'unknown'
                        # Move the file to the violated directory
                        dest_path = os.path.join(violated_dir, os.path.basename(full_path))
                        shutil.move(full_path, dest_path)
                        # Log the violation
                        log_message = f"{full_path} violate file detected. Uploaded by {uploader}."
                        logging.info(log_message, extra={'hostname': hostname})
if __name__ == '__main__':
    monitor_log()
# ----------

sudo chmod +x /usr/local/bin/sftp_watchd

sudo chown root:adm /var/log/sftp.log
sudo chmod 640 /var/log/sftp.log

sudo touch /var/log/sftp_watchd.log
sudo chown root:adm /var/log/sftp_watchd.log
sudo chmod 640 /var/log/sftp_watchd.log

# Create the RC Script for sftp_watchd Service
sudo vim /etc/init.d/sftp_watchd
# ----------
#!/bin/sh
### BEGIN INIT INFO
# Provides:          sftp_watchd
# Required-Start:    $remote_fs $syslog
# Required-Stop:     $remote_fs $syslog
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: SFTP Watch Daemon
# Description:       Monitors SFTP uploads and handles violations
### END INIT INFO

DAEMON=/usr/local/bin/sftp_watchd
DAEMON_NAME=sftp_watchd
PIDFILE=/var/run/$DAEMON_NAME.pid
LOGFILE=/var/log/$DAEMON_NAME.log

. /lib/lsb/init-functions

start_daemon() {
    log_daemon_msg "Starting $DAEMON_NAME"
    start-stop-daemon --start --background --make-pidfile --pidfile $PIDFILE --exec $DAEMON
    log_end_msg $?
}

stop_daemon() {
    if [ -f $PIDFILE ]; then
        PID=$(cat $PIDFILE)
        log_daemon_msg "Stopping $DAEMON_NAME"
        start-stop-daemon --stop --pidfile $PIDFILE --retry 10
        rm -f $PIDFILE
        log_end_msg $?
    else
        log_daemon_msg "$DAEMON_NAME is not running"
        log_end_msg 1
    fi
}

case "$1" in
    start)
        start_daemon
        ;;
    stop)
        stop_daemon
        ;;
    restart)
        stop_daemon
        sleep 1
        start_daemon
        ;;
    status)
        if [ -f $PIDFILE ]; then
            PID=$(cat $PIDFILE)
            if [ -e /proc/$PID -a /proc/$PID/exe ]; then
                echo "$DAEMON_NAME is running as pid $PID."
            else
                echo "$DAEMON_NAME is not running, but pid file exists."
            fi
        else
            echo "$DAEMON_NAME is not running."
        fi
        ;;
    *)
        echo "Usage: service $DAEMON_NAME {start|stop|restart|status}"
        exit 1
        ;;
esac

exit 0
# ----------

sudo chmod +x /etc/init.d/sftp_watchd
sudo update-rc.d sftp_watchd defaults
sudo service sftp_watchd start
sudo service sftp_watchd status

# HW 3-3: ZFS & Backup (54%)

