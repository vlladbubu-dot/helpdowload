#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo "Запусти с sudo!"
    exit 1
fi

systemctl stop unattended-upgrades 2>/dev/null
systemctl disable unattended-upgrades 2>/dev/null

clear
echo "=========================================="
echo "       Помощник в настройке вашего сервера"
echo "=========================================="
echo ""
echo "1. Сайт"
echo "2. Панель 3x-ui (REALITY + XHTTP)"
echo "3. Сайт + Панель 3x-ui"
echo "4. Python скрипт/бот"
echo "5. Fail2ban"
echo ""
read -p "Выбери [1-5]: " choice

case $choice in
    1)
        read -p "Домен: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/$DOMAIN/html;
    location /.well-known/acme-challenge/ {
        root /var/www/$DOMAIN/html;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
        else
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/html;
    location /.well-known/acme-challenge/ {
        root /var/www/$DOMAIN/html;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
        fi
        
        ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        
        systemctl stop nginx
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN
        else
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        fi
        systemctl start nginx
        
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    root /var/www/$DOMAIN/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        else
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    root /var/www/$DOMAIN/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        fi
        
        systemctl restart nginx
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        echo ""
        echo "✅ Сайт: https://$DOMAIN"
        echo ""
        echo "📁 Файлы сайта: /var/www/$DOMAIN/html/"
        echo "💡 ufw allow 80,443/tcp"
        echo ""
        ;;
    
    2)
        apt update -y
        apt install -y ufw curl wget sqlite3 openssl
        
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        sleep 3
        systemctl stop x-ui
        
        PANEL_PORT=5467
        REALITY_PORT=5555
        XHTTP_PORT=4444
        WEB_BASE_PATH=$(openssl rand -hex 8)
        USERNAME=$(openssl rand -hex 5)
        PASSWORD=$(openssl rand -hex 8)
        
        REALITY_ID=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        XHTTP_ID=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        
        REALITY_KEYS=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519)
        REALITY_PRIVATE=$(echo "$REALITY_KEYS" | grep "Private key:" | awk '{print $3}')
        REALITY_PUBLIC=$(echo "$REALITY_KEYS" | grep "Public key:" | awk '{print $3}')
        REALITY_SHORT_ID=$(openssl rand -hex 8)
        
        XHTTP_PATH=$(openssl rand -hex 10)
        
        /usr/local/x-ui/x-ui setting -username "$USERNAME" -password "$PASSWORD" -port "$PANEL_PORT" -webBasePath "$WEB_BASE_PATH"
        
        ufw allow "$PANEL_PORT"/tcp
        ufw allow "$REALITY_PORT"/tcp
        ufw allow "$XHTTP_PORT"/tcp
        
        sqlite3 /etc/x-ui/x-ui.db <<EOF
DELETE FROM inbounds;
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES 
('1','0','0','0','🇷🇺 REALITY','1','0','','$REALITY_PORT','vless','{\"clients\":[{\"id\":\"$REALITY_ID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"reality\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}','{\"network\":\"tcp\",\"security\":\"reality\",\"realitySettings\":{\"show\":false,\"xver\":0,\"target\":\"www.google.com\",\"serverNames\":[\"www.google.com\"],\"privateKey\":\"$REALITY_PRIVATE\",\"shortIds\":[\"$REALITY_SHORT_ID\"],\"settings\":{\"publicKey\":\"$REALITY_PUBLIC\",\"fingerprint\":\"chrome\",\"serverName\":\"\",\"spiderX\":\"/\"}}}','inbound-reality','{\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}'),
('1','0','0','0','🇷🇺 XHTTP','1','0','/dev/shm/xhttp.sock,0666','0','vless','{\"clients\":[{\"id\":\"$XHTTP_ID\",\"flow\":\"\",\"email\":\"xhttp\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}','{\"network\":\"xhttp\",\"security\":\"none\",\"xhttpSettings\":{\"path\":\"/$XHTTP_PATH\",\"host\":\"\",\"mode\":\"packet-up\"}}','inbound-xhttp','{\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}');
EOF
        
        systemctl start x-ui
        
        SERVER_IP=$(curl -s ifconfig.me)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        echo "═══════════════════════════════════════════"
        echo "🔗 ДОСТУП К ПАНЕЛИ:"
        echo "🌐 http://$SERVER_IP:$PANEL_PORT/$WEB_BASE_PATH"
        echo "🔐 Username: $USERNAME"
        echo "🔐 Password: $PASSWORD"
        echo ""
        echo "📡 ИНБАУНДЫ:"
        echo ""
        echo "▶ REALITY (рекомендуется с доменом):"
        echo "   Порт: $REALITY_PORT"
        echo "   ID: $REALITY_ID"
        echo "   PublicKey: $REALITY_PUBLIC"
        echo "   ShortId: $REALITY_SHORT_ID"
        echo ""
        echo "▶ XHTTP (без домена):"
        echo "   Порт: $XHTTP_PORT"
        echo "   ID: $XHTTP_ID"
        echo "   Path: /$XHTTP_PATH"
        echo ""
        echo "═══════════════════════════════════════════"
        echo "💡 СОХРАНИ ЭТИ ДАННЫЕ!"
        echo "🔓 Порты открыты: $PANEL_PORT, $REALITY_PORT, $XHTTP_PORT"
        echo ""
        ;;
    
    3)
        echo "Устанавливаю панель..."
        apt update -y
        apt install -y ufw curl wget sqlite3 openssl
        
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        sleep 3
        systemctl stop x-ui
        
        PANEL_PORT=5467
        REALITY_PORT=5555
        XHTTP_PORT=4444
        WEB_BASE_PATH=$(openssl rand -hex 8)
        USERNAME=$(openssl rand -hex 5)
        PASSWORD=$(openssl rand -hex 8)
        
        REALITY_ID=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        XHTTP_ID=$(/usr/local/x-ui/bin/xray-linux-amd64 uuid)
        
        REALITY_KEYS=$(/usr/local/x-ui/bin/xray-linux-amd64 x25519)
        REALITY_PRIVATE=$(echo "$REALITY_KEYS" | grep "Private key:" | awk '{print $3}')
        REALITY_PUBLIC=$(echo "$REALITY_KEYS" | grep "Public key:" | awk '{print $3}')
        REALITY_SHORT_ID=$(openssl rand -hex 8)
        
        XHTTP_PATH=$(openssl rand -hex 10)
        
        /usr/local/x-ui/x-ui setting -username "$USERNAME" -password "$PASSWORD" -port "$PANEL_PORT" -webBasePath "$WEB_BASE_PATH"
        
        ufw allow "$PANEL_PORT"/tcp
        ufw allow "$REALITY_PORT"/tcp
        ufw allow "$XHTTP_PORT"/tcp
        
        sqlite3 /etc/x-ui/x-ui.db <<EOF
DELETE FROM inbounds;
INSERT INTO "inbounds" ("user_id","up","down","total","remark","enable","expiry_time","listen","port","protocol","settings","stream_settings","tag","sniffing") VALUES 
('1','0','0','0','🇷🇺 REALITY','1','0','','$REALITY_PORT','vless','{\"clients\":[{\"id\":\"$REALITY_ID\",\"flow\":\"xtls-rprx-vision\",\"email\":\"reality\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}','{\"network\":\"tcp\",\"security\":\"reality\",\"realitySettings\":{\"show\":false,\"xver\":0,\"target\":\"www.google.com\",\"serverNames\":[\"www.google.com\"],\"privateKey\":\"$REALITY_PRIVATE\",\"shortIds\":[\"$REALITY_SHORT_ID\"],\"settings\":{\"publicKey\":\"$REALITY_PUBLIC\",\"fingerprint\":\"chrome\",\"serverName\":\"\",\"spiderX\":\"/\"}}}','inbound-reality','{\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}'),
('1','0','0','0','🇷🇺 XHTTP','1','0','/dev/shm/xhttp.sock,0666','0','vless','{\"clients\":[{\"id\":\"$XHTTP_ID\",\"flow\":\"\",\"email\":\"xhttp\",\"limitIp\":0,\"totalGB\":0,\"expiryTime\":0,\"enable\":true}],\"decryption\":\"none\",\"fallbacks\":[]}','{\"network\":\"xhttp\",\"security\":\"none\",\"xhttpSettings\":{\"path\":\"/$XHTTP_PATH\",\"host\":\"\",\"mode\":\"packet-up\"}}','inbound-xhttp','{\"enabled\":true,\"destOverride\":[\"http\",\"tls\"]}');
EOF
        
        systemctl start x-ui
        
        SERVER_IP=$(curl -s ifconfig.me)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        echo "═══════════════════════════════════════════"
        echo "🔗 ДОСТУП К ПАНЕЛИ:"
        echo "🌐 http://$SERVER_IP:$PANEL_PORT/$WEB_BASE_PATH"
        echo "🔐 Username: $USERNAME"
        echo "🔐 Password: $PASSWORD"
        echo ""
        echo "📡 ИНБАУНДЫ:"
        echo ""
        echo "▶ REALITY:"
        echo "   Порт: $REALITY_PORT"
        echo "   ID: $REALITY_ID"
        echo "   PublicKey: $REALITY_PUBLIC"
        echo "   ShortId: $REALITY_SHORT_ID"
        echo ""
        echo "▶ XHTTP:"
        echo "   Порт: $XHTTP_PORT"
        echo "   ID: $XHTTP_ID"
        echo "   Path: /$XHTTP_PATH"
        echo "═══════════════════════════════════════════"
        echo ""
        
        read -p "Нажми Enter, чтобы продолжить установку сайта..."
        
        read -p "Домен: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    root /var/www/$DOMAIN/html;
    location /.well-known/acme-challenge/ {
        root /var/www/$DOMAIN/html;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
        else
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/html;
    location /.well-known/acme-challenge/ {
        root /var/www/$DOMAIN/html;
    }
    location / {
        return 301 https://\$server_name\$request_uri;
    }
}
EOF
        fi
        
        ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        
        systemctl stop nginx
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN
        else
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        fi
        systemctl start nginx
        
        if [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]] || [[ "$DOMAIN" =~ ^[a-zA-Z0-9-]+\.[a-zA-Z0-9-]+\.[a-zA-Z]{2,}$ ]]; then
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    root /var/www/$DOMAIN/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        else
            cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    return 301 https://\$server_name\$request_uri;
}
server {
    listen 443 ssl http2;
    server_name $DOMAIN www.$DOMAIN;
    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;
    root /var/www/$DOMAIN/html;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
        fi
        
        systemctl restart nginx
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        echo ""
        echo "✅ Сайт: https://$DOMAIN"
        echo "📁 Файлы сайта: /var/www/$DOMAIN/html/"
        echo "💡 ufw allow 80,443/tcp"
        echo ""
        ;;
    
    4)
        mkdir -p /my_bots/test
        cd /my_bots/test
        
        cat > main.py <<EOF
import time
import datetime

def main():
    print(f"Бот запущен: {datetime.datetime.now()}")
    while True:
        print("Работаю...")
        time.sleep(60)

if __name__ == "__main__":
    main()
EOF
        
        apt install -y python3.12-venv
        python3 -m venv venv
        source venv/bin/activate
        
        mkdir -p systemd
        cat > systemd/test.service <<EOF
[Unit]
Description=test
After=syslog.target
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/my_bots/test/
ExecStart=/my_bots/test/venv/bin/python3 /my_bots/test/main.py
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        apt install -y systemd
        systemctl daemon-reload
        systemctl enable /my_bots/test/systemd/test.service
        systemctl start test
        
        echo ""
        echo "✅ Python скрипт установлен и запущен"
        echo "📁 Папка: /my_bots/test/"
        echo ""
        echo "🔧 Управление: systemctl stop/start/restart/status test"
        echo "📋 Логи: journalctl -u test -f"
        echo ""
        ;;
    
    5)
        apt update -y
        apt install -y fail2ban
        
        cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = -1
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = -1

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
bantime = -1
EOF
        
        systemctl restart fail2ban
        systemctl enable fail2ban
        
        echo ""
        echo "✅ Fail2ban установлен"
        echo "📝 Максимум попыток: 3"
        echo "⏱️ Время бана: навсегда"
        echo ""
        echo "🔧 Команды:"
        echo "📋 Статус: fail2ban-client status sshd"
        echo "🔓 Разбанить IP: fail2ban-client set sshd unbanip IP"
        echo ""
        ;;
    
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

systemctl enable unattended-upgrades 2>/dev/null
systemctl start unattended-upgrades 2>/dev/null
