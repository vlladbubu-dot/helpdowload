#!/bin/bash

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo "Запусти с sudo!"
    exit 1
fi

clear
echo "=========================================="
echo "       Универсальный установщик"
echo "=========================================="
echo ""
echo "1. Установить сайт (Nginx + SSL)"
echo "2. Установить панель 3x-ui"
echo "3. Установить всё вместе"
echo ""
read -p "Выбери [1-3]: " choice

case $choice in
    1)
        read -p "Домен: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
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
        
        ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        
        systemctl stop nginx
        certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        systemctl start nginx
        
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
        
        systemctl restart nginx
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        echo ""
        echo "✅ Сайт: https://$DOMAIN"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА"
        echo ""
        ;;
    
    2)
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА ДЛЯ ПАНЕЛИ"
        echo "⚠️ ПОТОМ ОТКРОЙ ПОРТЫ ДЛЯ ИНБАУНДОВ"
        echo ""
        ;;
    
    3)
        echo "Устанавливаю панель..."
        bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)
        
        echo ""
        echo "✅ Панель установлена"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА ДЛЯ ПАНЕЛИ"
        echo "⚠️ ПОТОМ ОТКРОЙ ПОРТЫ ДЛЯ ИНБАУНДОВ"
        echo ""
        
        read -p "Нажми Enter, чтобы продолжить установку сайта..."
        
        read -p "Домен для сайта: " DOMAIN
        [[ -z "$DOMAIN" ]] && echo "Ошибка" && exit 1
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx
        
        mkdir -p /var/www/$DOMAIN/html
        echo "<h1>$DOMAIN работает</h1>" > /var/www/$DOMAIN/html/index.html
        
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
        
        ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
        rm -f /etc/nginx/sites-enabled/default
        systemctl restart nginx
        
        systemctl stop nginx
        certbot certonly --standalone --agree-tos --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
        systemctl start nginx
        
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
        
        systemctl restart nginx
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        echo ""
        echo "✅ Сайт: https://$DOMAIN"
        echo ""
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА ДЛЯ САЙТА"
        echo ""
        ;;
    
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac
