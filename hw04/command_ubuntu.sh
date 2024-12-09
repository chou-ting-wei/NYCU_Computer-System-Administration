# --------------------
# Sysdig
# --------------------
sudo apt update
sudo apt install sysdig -y

# sudo sysdig -c spy_users user.name=judge

sudo touch /var/log/sysdig_judge.log
sudo chown root:root /var/log/sysdig_judge.log
sudo chmod 600 /var/log/sysdig_judge.log
sudo touch /var/log/sysdig_judge_error.log
sudo chown root:root /var/log/sysdig_judge_error.log
sudo chmod 600 /var/log/sysdig_judge_error.log

sudo apt install -y expect
sudo vim /etc/systemd/system/sysdig_judge.service
sudo systemctl daemon-reload
sudo systemctl enable sysdig_judge.service
sudo systemctl start sysdig_judge.service
sudo systemctl status sysdig_judge.service

sudo tail -F /var/log/sysdig_judge.log

# --------------------
# Install Required Software
# --------------------
sudo apt update
# OpenResty
sudo apt-get -y install --no-install-recommends wget gnupg ca-certificates lsb-release
wget -O - https://openresty.org/package/pubkey.gpg | sudo gpg --dearmor -o /usr/share/keyrings/openresty.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/openresty.gpg] http://openresty.org/package/ubuntu $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/openresty.list > /dev/null
sudo apt-get update
sudo apt-get -y install openresty

sudo apt install openssl -y
sudo apt install net-tools -y
sudo apt install postgresql postgresql-contrib -y
# --------------------
# Virtual Host
# --------------------
sudo systemctl daemon-reload
sudo systemctl enable openresty
sudo systemctl start openresty
sudo systemctl status openresty

sudo apt update
sudo apt install dnsmasq -y
sudo vim /etc/dnsmasq.d/wildcard.conf
# ----------
address=/.88.cs.nycu/10.113.88.11
# ----------

sudo vim /etc/systemd/resolved.conf
# ----------
DNSStubListener=no
DNS=127.0.0.1
FallbackDNS=8.8.8.8
# ----------

sudo vim /etc/hosts
# ----------
192.168.88.1 sa2024-88
# ----------

sudo systemctl restart systemd-resolved
sudo systemctl status systemd-resolved
sudo systemctl restart dnsmasq
sudo systemctl status dnsmasq

dig nasa.88.cs.nycu
dig file.88.cs.nycu
dig adminer.88.cs.nycu
dig unknown.88.cs.nycu

# --------------------
# Hide Server Information
# --------------------
sudo apt install nginx-extras -y
sudo vim /usr/local/openresty/nginx/conf/nginx.conf
# ----------
http {
    server_tokens off;
    more_set_headers "Server: nginx";
}
# ----------

sudo openresty -t
sudo systemctl reload openresty

curl -I nasa.88.cs.nycu

# --------------------
# Generate SSL Certificate
# --------------------
mkdir -p ~/myCA/{certs,crl,newcerts,private}
chmod 700 ~/myCA/private
cd ~/myCA

touch index.txt
echo 1000 > serial

vim ca.cnf

openssl genrsa -out private/ca.key.pem 4096
chmod 400 private/ca.key.pem

openssl req -config ca.cnf \
    -key private/ca.key.pem \
    -new -x509 -days 3650 -sha256 -extensions v3_ca \
    -out certs/ca.cert.pem

vim server_cert.cnf

openssl genrsa -out private/server.key.pem 2048
chmod 400 private/server.key.pem

openssl req -config server_cert.cnf -new -key private/server.key.pem -out server.csr.pem

openssl ca -config ca.cnf -extensions v3_ca \
    -days 375 -notext -md sha256 \
    -in server.csr.pem \
    -out certs/server.cert.pem

openssl x509 -in certs/ca.cert.pem -noout -subject
openssl x509 -in certs/server.cert.pem -noout -subject

sudo mkdir -p /usr/local/openresty/nginx/conf/ssl
sudo cp certs/server.cert.pem /usr/local/openresty/nginx/conf/ssl/88.cs.nycu.crt
sudo cp private/server.key.pem /usr/local/openresty/nginx/conf/ssl/88.cs.nycu.key
sudo cp certs/ca.cert.pem /home/judge/ca.crt
sudo openssl x509 -in /home/judge/ca.crt -noout -subject

sudo cp certs/ca.cert.pem /usr/local/share/ca-certificates/88-ca.crt
sudo update-ca-certificates

# --------------------
# Implement Access Control
# --------------------
sudo apt install apache2-utils -y
echo "10.113.88.11" | tr -d '.' | sudo htpasswd -c -i /usr/local/openresty/nginx/conf/.htpasswd sa-admin
sudo chmod 644 /usr/local/openresty/nginx/conf/.htpasswd
sudo cat /usr/local/openresty/nginx/conf/.htpasswd

sudo openresty -t
sudo systemctl reload openresty

curl -i https://nasa.88.cs.nycu
curl -i https://nasa.88.cs.nycu -u sa-admin:101138811

# --------------------
# Configure Logging
# --------------------
sudo mkdir -p /home/judge/webserver/log
sudo chown -R www-data:www-data /home/judge/webserver/log

# ----------
server {
    access_log /home/judge/webserver/log/access.log combined if=$loggable;
}
# ----------

sudo vim /usr/local/openresty/nginx/conf/nginx.conf
# ----------
http {
    map $http_user_agent $loggable {
        default 1;
        "~*no-logging" 0;
    }
}
# ----------

sudo openresty -t
sudo systemctl reload openresty

sudo tail -F /home/judge/webserver/log/access.log

sudo vim /usr/local/openresty/nginx/conf/nginx.conf
# ----------
http {
    lua_need_request_body on;
}
# ----------

# ----------
access_by_lua_block {
    ngx.req.read_body()
    local req_body = ngx.req.get_body_data()
    if not req_body then
        local req_body_file = ngx.req.get_body_file()
        if req_body_file then
            local file = io.open(req_body_file, "rb")
            if file then
                req_body = file:read("*all")
                file:close()
            end
        end
    end
    ngx.ctx.request_body = req_body or ""
}

body_filter_by_lua_block {
    local resp_body = ngx.ctx.buffered or ""
    resp_body = resp_body .. (ngx.arg[1] or "")
    if ngx.arg[2] then
        ngx.ctx.response_body = resp_body
    else
        ngx.ctx.buffered = resp_body
    end
}

log_by_lua_block {
    if ngx.var.loggable == "1" then
        local cjson = require "cjson.safe"
        local status = ngx.status

        local req_headers = ngx.req.get_headers()
        local req_body = ngx.ctx.request_body or ""
        local resp_headers = ngx.resp.get_headers()
        local resp_body = ngx.ctx.response_body or ""

        local function format_headers(headers)
            local formatted = ""
            for k, v in pairs(headers) do
                formatted = formatted .. string.format("%s: %s\n", k, v)
            end
            return formatted
        end

        local log_content = "Request Headers:\n" ..
                            format_headers(req_headers) .. "\n" ..
                            "Request Body:\n" ..
                            (req_body ~= "" and req_body or "") .. "\n\n" ..
                            "Response Headers:\n" ..
                            format_headers(resp_headers) .. "\n" ..
                            "Response Body:\n" ..
                            (resp_body ~= "" and resp_body or "") .. "\n"

        local log_base64 = ngx.encode_base64(log_content)
        local log_line = string.format("STATUS: %s\t%s", status, log_base64)

        local file, err = io.open("/home/judge/webserver/log/access.log", "a")
        if not file then
            ngx.log(ngx.ERR, "Failed to open log file: ", err)
        else
            file:write(log_line, "\n")
            file:close()
        end
}
# ----------

sudo apt-get install luarocks -y
luarocks install lua-resty-string
luarocks install lua-cjson
sudo chmod o+x /home/judge
sudo tail -F /home/judge/webserver/log/access.log
sudo tail -F /usr/local/openresty/nginx/logs/error.log

curl -u sa-admin:101138811 -kL -s --location-trusted \
    -H "User-Agent: curl/2024-sa@sEf4A" \
    -H "header-random: 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" \
    https://nasa.88.cs.nycu

curl -u sa-admin:101138811 -kL -s --location-trusted \
    -H "User-Agent: curl/2024-sa@sEf4A-no-logging" \
    -H "header-random: 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" \
    https://nasa.88.cs.nycu

# --------------------
# Log Rotation
# --------------------

sudo vim /home/judge/rotate_log.sh
sudo chmod +x /home/judge/rotate_log.sh

sudo vim /etc/systemd/system/logrotate.service

sudo systemctl daemon-reload
sudo systemctl start logrotate.service
sudo systemctl enable logrotate.service
sudo systemctl status logrotate.service

sudo ls /home/judge/webserver/log/

# --------------------
# Deploy PostgreSQL
# --------------------
ip -c a
sudo ip link set dev enp0s8 up
sudo ip addr add dev enp0s8 192.168.88.1/24
sudo vim /etc/systemd/system/setup-enp0s8.service
sudo systemctl daemon-reload
sudo systemctl start setup-enp0s8.service
sudo systemctl enable setup-enp0s8.service
sudo systemctl status setup-enp0s8.service

sudo vim /etc/postgresql/16/main/postgresql.conf
# ----------
listen_addresses = 'localhost,192.168.88.1'
# ----------

sudo vim /etc/postgresql/16/main/pg_hba.conf
# ----------
host    all             all             192.168.88.0/24          md5
# ----------`
sudo systemctl restart postgresql

sudo -i -u postgres
createuser root --superuser --pwprompt
createuser judge --pwprompt
# sa-hw4-88
psql
# ----------`
CREATE DATABASE "sa-hw4";
GRANT ALL PRIVILEGES ON DATABASE "sa-hw4" TO judge;
\q
# ----------`
exit

sudo vim /etc/environment
# ----------
export PGPASSWORD='sa-hw4-88'
# ----------
source /etc/environment

psql -U root -h 192.168.88.1 -d sa-hw4
# ----------`
CREATE SEQUENCE user_id_seq START WITH 1 INCREMENT BY 1;

CREATE TABLE "user" (
    id INTEGER DEFAULT nextval('user_id_seq') PRIMARY KEY,
    name TEXT,
    age INTEGER,
    birthday DATE
);
# ----------`
\dt
\d user
\q

# Flask backend
sudo apt update
sudo apt install python3-pip python3.12-venv -y

mkdir backend
cd backend
mkdir uploads
vim app.py

tmux
python3 -m venv .venv
source .venv/bin/activate 
pip install flask flask_sqlalchemy flask_cors psycopg2-binary
python app.py

curl -i -X GET http://192.168.88.1:8080/ip
curl -i -X GET http://192.168.88.1:8080/db/dsxvczqrot
curl -i -X GET http://192.168.88.1:8080/db/dsxvczqro

touch test.txt
curl -i -X POST -F "file=@./test.txt" http://192.168.88.1:8080/upload
rm test.txt
curl -i -X GET http://192.168.88.1:8080/file/test.txt
curl -i -X GET http://192.168.88.1:8080/file/tes.txt

# --------------------
# Configure 192.168.88.2 Host
# --------------------
echo "twchou ALL=(ALL) NOPASSWD: ALL" | sudo tee /etc/sudoers.d/twchou
sudo chmod 440 /etc/sudoers.d/twchou

# Change all 192.168.88.1 to 192.168.88.2
ip -c a
sudo ip link set dev enp0s8 up
sudo ip addr add dev enp0s8 192.168.88.2/24
sudo vim /etc/systemd/system/setup-enp0s8.service
sudo systemctl daemon-reload
sudo systemctl start setup-enp0s8.service
sudo systemctl enable setup-enp0s8.service
sudo systemctl status setup-enp0s8.service

sudo vim /etc/hosts
# ----------
192.168.88.2 sa2024-88-bk
# ----------

sudo apt update
sudo apt install python3-pip python3.12-venv -y

mkdir backend
cd backend
mkdir uploads
vim app.py

tmux
python3 -m venv .venv
source .venv/bin/activate 
pip install flask flask_sqlalchemy flask_cors psycopg2-binary
python app.py

curl -i -X GET http://192.168.88.2:8080/ip

touch test2.txt
curl -i -X POST -F "file=@./test2.txt" http://192.168.88.2:8080/upload
rm test2.txt
curl -i -X GET http://192.168.88.2:8080/file/test2.txt
curl -i -X GET http://192.168.88.2:8080/file/tes.txt

# --------------------
# NFS Server & Client
# --------------------
# NFS Server (192.168.88.2)
sudo apt-get update
sudo apt-get install nfs-kernel-server -y

sudo mkdir -p /data
sudo chown 1001:1001 /data
sudo chmod 755 /data

sudo vim /etc/exports
# ----------
/data 192.168.88.0/24(rw,sync,root_squash,no_subtree_check)
# ----------

sudo exportfs -a
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

sudo iptables -A INPUT -p tcp -s 192.168.88.0/24 --dport 2049 -j ACCEPT
sudo iptables -A INPUT -p udp -s 192.168.88.0/24 --dport 2049 -j ACCEPT
sudo iptables -A INPUT -p tcp -s 192.168.88.0/24 --dport 111 -j ACCEPT
sudo iptables -A INPUT -p udp -s 192.168.88.0/24 --dport 111 -j ACCEPT
sudo iptables -A INPUT -p tcp -s 192.168.88.0/24 --dport 20048 -j ACCEPT
sudo iptables -A INPUT -p udp -s 192.168.88.0/24 --dport 20048 -j ACCEPT

sudo netfilter-persistent save
sudo iptables -L -v --line-numbers

# NFS Client (192.168.88.1)
sudo apt-get update
sudo apt-get install nfs-common -y

sudo mkdir -p /net/data
sudo chown $(whoami):$(whoami) /net/data
sudo mount -t nfs 192.168.88.2:/data /net/data
df -h | grep /net/data

sudo vim /etc/fstab
# ----------
192.168.88.2:/data  /net/data  nfs  defaults  0  0
# ----------

# --------------------
# Synchronizing Files
# --------------------
# NFS Server (192.168.88.2)
sudo mkdir -p /home/twchou/backend/uploads
sudo chown -R twchou:twchou /home/twchou/backend/uploads
sudo chmod 755 /home/twchou/backend/uploads
sudo vim /etc/exports
# ----------
/home/twchou/backend/uploads 192.168.88.1(rw,sync,no_subtree_check)
# ----------

sudo exportfs -a
sudo systemctl restart nfs-kernel-server
sudo systemctl enable nfs-kernel-server

# NFS Client (192.168.88.1)
sudo mkdir -p /home/twchou/backend/uploads
sudo mount -t nfs 192.168.88.2:/home/twchou/backend/uploads /home/twchou/backend/uploads
df -h | grep /home/twchou/backend/uploads

sudo vim /etc/fstab
# ----------
192.168.88.2:/home/twchou/backend/uploads  /home/twchou/backend/uploads  nfs  defaults  0  0
# ----------

ls /home/twchou/backend/uploads

curl -i -X GET http://192.168.88.1:8080/file/test2.txt
curl -i -X GET http://192.168.88.2:8080/file/test.txt

touch test3.txt
curl -i -X POST -F "file=@./test3.txt" http://192.168.88.1:8080/upload
rm test3.txt

ls /home/twchou/backend/uploads

curl -i https://file.88.cs.nycu/

# --------------------
# Adminer
# --------------------
sudo apt update
sudo apt install -y docker.io
sudo systemctl start docker
sudo systemctl enable docker

sudo curl -L "https://github.com/docker/compose/releases/download/v2.30.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version

mkdir adminer-docker
cd adminer-docker
vim docker-compose.yml
sudo docker-compose up -d
sudo docker-compose ps

curl http://localhost:6064/

curl -i https://adminer.88.cs.nycu

# --------------------
# Configure Nginx Virtual Hosts
# --------------------
sudo mkdir -p /usr/local/openresty/nginx/conf/sites-available
sudo mkdir -p /usr/local/openresty/nginx/conf/sites-enabled
sudo vim /usr/local/openresty/nginx/conf/nginx.conf
# ----------
http {
    include /usr/local/openresty/nginx/conf/sites-enabled/*;
}
# ----------

sudo mkdir -p /var/www/nasa.88.cs.nycu
echo '2024-nycu.sa-hw4-vhost' | sudo tee /var/www/nasa.88.cs.nycu/index.txt > /dev/null

sudo vim /usr/local/openresty/nginx/conf/sites-available/nasa.88.cs.nycu
sudo ln -s /usr/local/openresty/nginx/conf/sites-available/nasa.88.cs.nycu /usr/local/openresty/nginx/conf/sites-enabled/

sudo vim /usr/local/openresty/nginx/conf/sites-available/file.88.cs.nycu
sudo ln -s /usr/local/openresty/nginx/conf/sites-available/file.88.cs.nycu /usr/local/openresty/nginx/conf/sites-enabled/

sudo vim  /usr/local/openresty/nginx/conf/sites-available/adminer.88.cs.nycu
sudo ln -s  /usr/local/openresty/nginx/conf/sites-available/adminer.88.cs.nycu /usr/local/openresty/nginx/conf/sites-enabled/

sudo vim /usr/local/openresty/nginx/conf/sites-available/wildcard.88.cs.nycu
sudo ln -s /usr/local/openresty/nginx/conf/sites-available/wildcard.88.cs.nycu /usr/local/openresty/nginx/conf/sites-enabled/
curl -i https://unknown.88.cs.nycu

sudo openresty -t
sudo systemctl reload openresty

# --------------------
# Firewall
# --------------------
sudo iptables-save > ~/iptables-backup-$(date +%F).rules

sudo iptables -F
sudo iptables -X
sudo iptables -Z

sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT

sudo iptables -A INPUT -p icmp --icmp-type echo-request -s 192.168.88.0/24 -j ACCEPT
sudo iptables -A INPUT -p icmp --icmp-type echo-request -j DROP
sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -s 192.168.88.0/24 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8080 -j DROP
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
sudo iptables -A INPUT -i lo -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

sudo iptables -P INPUT DROP

sudo apt-get install iptables-persistent -y
sudo netfilter-persistent save
sudo iptables -L -v --line-numbers

# --------------------
# Fail2Ban
# --------------------
sudo apt-get update
sudo apt-get install fail2ban -y

sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo vim /etc/fail2ban/jail.local
# ----------
[sshd]
enabled = true
port    = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s

maxretry = 3
findtime = 5m
bantime  = 60s
# ----------

sudo systemctl start fail2ban
sudo systemctl enable fail2ban

sudo fail2ban-client status
sudo fail2ban-client status sshd
