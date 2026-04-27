#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции вывода
print_ok() { echo -e "${GREEN}[✓]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# Проверка root
if [[ $EUID -ne 0 ]]; then
    print_error "Запусти с sudo!"
    exit 1
fi

# Главное меню
clear
echo "=========================================="
echo "       🚀 Универсальный установщик"
echo "=========================================="
echo ""
echo "1. Установить Nginx + SSL (для сайта)"
echo "2. Установить 3x-ui панель"
echo "3. Установить ВСЁ (Nginx + SSL + 3x-ui)"
echo ""
read -p "Выбери вариант [1-3]: " choice

case $choice in
    1)
        # ============ Установка Nginx + SSL ============
        clear
        print_header "Установка Nginx + SSL"
        
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx ufw
        
        read -p "Введи домен (example.com): " DOMAIN
        
        mkdir -p /var/www/$DOMAIN/html
        cat > /var/www/$DOMAIN/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>$DOMAIN</title></head>
<body>
<h1>✅ Сайт работает!</h1>
<p>SSL активен для $DOMAIN</p>
</body>
</html>
EOF
        
        cat > /etc/nginx/sites-available/$DOMAIN <<EOF
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;
    root /var/www/$DOMAIN/html;
    index index.html;
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
        certbot certonly --standalone --non-interactive --agree-tos \
            --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
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
        
        ufw allow 80,443,22/tcp
        echo "y" | ufw enable
        
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        print_ok "Готово! Сайт: https://$DOMAIN"
        ;;
    
    2)
        # ============ Установка 3x-ui ============
        clear
        print_header "Установка 3x-ui панели"
        
        apt update -y
        apt install -y curl tar ufw
        
        print_info "Скачиваю 3x-ui..."
        curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash
        
        print_info "Открываю порт 54321 для панели..."
        ufw allow 54321/tcp
        ufw allow 443/tcp
        ufw allow 80/tcp
        echo "y" | ufw enable
        
        print_warn "ВАЖНО! Открой эти порты в фаерволе хостинга:"
        echo "   ➜ TCP: 54321 (панель)"
        echo "   ➜ TCP: 443 (VLESS/VMESS)"
        echo "   ➜ TCP: 80 (HTTP)"
        echo ""
        print_info "Доступ к панели: http://IP_СЕРВЕРА:54321"
        print_info "Логин/пароль покажет после установки"
        ;;
    
    3)
        # ============ Установка ВСЕГО ============
        clear
        print_header "Полная установка (Nginx + SSL + 3x-ui)"
        
        read -p "Введи домен (example.com): " DOMAIN
        
        # Установка Nginx + SSL
        apt update -y
        apt install -y nginx certbot python3-certbot-nginx ufw curl tar
        
        mkdir -p /var/www/$DOMAIN/html
        cat > /var/www/$DOMAIN/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><title>$DOMAIN</title></head>
<body><h1>✅ Сайт работает!</h1></body>
</html>
EOF
        
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
        certbot certonly --standalone --non-interactive --agree-tos \
            --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN
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
        
        # Установка 3x-ui
        print_info "Устанавливаю 3x-ui..."
        curl -fsSL https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh | bash
        
        # Настройка фаервола
        ufw allow 80,443,22,54321/tcp
        echo "y" | ufw enable
        
        # Автообновление сертификата
        (crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
        
        # Финальный вывод
        clear
        print_header "УСТАНОВКА ЗАВЕРШЕНА!"
        echo ""
        echo "🌐 САЙТ: https://$DOMAIN"
        echo "📊 ПАНЕЛЬ: http://IP_СЕРВЕРА:54321"
        echo ""
        print_warn "⚠️  ВАЖНО! Открой порты в фаерволе хостинга:"
        echo ""
        echo "   ┌─────────────────────────────────────┐"
        echo "   │  TCP 80    → HTTP (для сертификата) │"
        echo "   │  TCP 443   → HTTPS (сайт и VLESS)   │"
        echo "   │  TCP 54321 → Панель 3x-ui           │"
        echo "   └─────────────────────────────────────┘"
        echo ""
        print_info "Логин/пароль от панели:"
        echo "   x-ui settings"
        echo ""
        ;;
    
    *)
        print_error "Неверный выбор!"
        exit 1
        ;;
esac