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
print_header() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}$1${NC}"
    echo "=========================================="
}

# Проверка root
if [[ $EUID -ne 0 ]]; then
    print_error "Запусти с sudo!"
    exit 1
fi

# Установка
clear
print_header "Установка Nginx + SSL"

apt update -y
apt install -y nginx certbot python3-certbot-nginx

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

(crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

clear
print_header "УСТАНОВКА ЗАВЕРШЕНА!"
echo ""
print_ok "Сайт: https://$DOMAIN"
echo ""
print_warn "⚠️  ВАЖНО! Открой порты в фаерволе хостинга:"
echo ""
echo "   ┌─────────────────────────────────────┐"
echo "   │  TCP 80    → HTTP (для сертификата) │"
echo "   │  TCP 443   → HTTPS (сайт)           │"
echo "   └─────────────────────────────────────┘"
echo ""
