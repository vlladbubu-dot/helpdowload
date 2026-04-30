#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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
echo "2. Панель 3x-ui"
echo "3. Сайт + Панель 3x-ui"
echo "4. Python скрипт/бот"
echo "5. Fail2ban"
echo ""
read -p "Выбери [1-5]: " choice

case $choice in
    1)
        read -p "Домен: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        if [[ $(echo "$DOMAIN" | grep -o '\.' | wc -l) -ge 2 ]]; then
            IS_SUBDOMAIN=true
        else
            IS_SUBDOMAIN=false
        fi
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
        if [[ "$IS_SUBDOMAIN" == true ]]; then
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
        if [[ "$IS_SUBDOMAIN" == true ]]; then
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN
        else
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        fi
        systemctl start nginx
        
        if [[ "$IS_SUBDOMAIN" == true ]]; then
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
        if [[ "$IS_SUBDOMAIN" == false ]]; then
            echo "✅ Также доступен: https://www.$DOMAIN"
        fi
        echo ""
        echo "📁 Файлы сайта: /var/www/$DOMAIN/html/"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ: sudo ufw allow 80,443/tcp"
        echo ""
        ;;
    
    2)
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        
        (echo "10") | x-ui
        
        echo ""
        echo -e "${RED}⚠️ ВНИМАНИЕ! ОТКРОЙТЕ ПОРТ В ФАЕРВОЛЕ ХОСТИНГА!${NC}"
        echo -e "${YELLOW}💡 Посмотри выше порт панели (например: 54321) и выполни:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ПАНЕЛИ/tcp${NC}"
        echo ""
        echo -e "${RED}⚠️ ДЛЯ КАЖДОГО ИНБАУНДА ТОЖЕ НУЖНО ОТКРЫВАТЬ ПОРТЫ!${NC}"
        echo -e "${YELLOW}💡 Когда добавишь инбаунд, его порт тоже надо открыть:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ИНБАУНДА/tcp${NC}"
        echo ""
        ;;
    
    3)
        echo "Устанавливаю панель..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        
        (echo "10") | x-ui
        
        echo ""
        echo -e "${RED}⚠️ ВНИМАНИЕ! ОТКРОЙТЕ ПОРТ В ФАЕРВОЛЕ ХОСТИНГА!${NC}"
        echo -e "${YELLOW}💡 Посмотри выше порт панели (например: 54321) и выполни:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ПАНЕЛИ/tcp${NC}"
        echo ""
        echo -e "${RED}⚠️ ДЛЯ КАЖДОГО ИНБАУНДА ТОЖЕ НУЖНО ОТКРЫВАТЬ ПОРТЫ!${NC}"
        echo -e "${YELLOW}💡 Когда добавишь инбаунд, его порт тоже надо открыть:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ИНБАУНДА/tcp${NC}"
        echo ""
        
        read -p "Нажми Enter, чтобы продолжить установку сайта..."
        
        read -p "Домен для сайта: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        if [[ $(echo "$DOMAIN" | grep -o '\.' | wc -l) -ge 2 ]]; then
            IS_SUBDOMAIN=true
        else
            IS_SUBDOMAIN=false
        fi
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
        if [[ "$IS_SUBDOMAIN" == true ]]; then
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
        if [[ "$IS_SUBDOMAIN" == true ]]; then
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN
        else
            certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        fi
        systemctl start nginx
        
        if [[ "$IS_SUBDOMAIN" == true ]]; then
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
        if [[ "$IS_SUBDOMAIN" == false ]]; then
            echo "✅ Также доступен: https://www.$DOMAIN"
        fi
        echo ""
        echo "📁 Файлы сайта: /var/www/$DOMAIN/html/"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ: sudo ufw allow 80,443/tcp"
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
        echo "📄 Файл: main.py"
        echo ""
        echo "🔧 Управление:"
        echo "💡 Остановить: systemctl stop test"
        echo "💡 Запустить: systemctl start test"
        echo "💡 Перезапустить: systemctl restart test"
        echo "💡 Статус: systemctl status test"
        echo "💡 Логи: journalctl -u test -f"
        echo ""
        echo "⚠️ nano /my_bots/test/main.py (после изменений: systemctl restart test)"
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
        echo "📝 Попыток: 3 | Бан: навсегда"
        echo ""
        echo "🔧 Команды:"
        echo "💡 Забаненные IP: fail2ban-client status sshd"
        echo "💡 Разбанить: fail2ban-client set sshd unbanip IP"
        echo ""
        ;;
    
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac

systemctl enable unattended-upgrades 2>/dev/null
systemctl start unattended-upgrades 2>/dev/null
