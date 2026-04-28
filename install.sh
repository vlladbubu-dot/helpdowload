#!/bin/bash

# Цвета
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "=========================================="
echo "       🚀 Установка Nginx + SSL"
echo "=========================================="
echo ""

# Проверка root
if [[ $EUID -ne 0 ]]; then
    echo "Запусти с sudo: sudo bash $0"
    exit 1
fi

# ЗАПРОС ДОМЕНА
echo -n "Введи домен (например: site.ru): "
read DOMAIN

if [[ -z "$DOMAIN" ]]; then
    echo "Ошибка: домен не введён!"
    exit 1
fi

echo ""
echo "Начинаю установку для домена: $DOMAIN"
echo ""

# Установка
apt update -y
apt install -y nginx certbot python3-certbot-nginx

# Создаём папку и тестовую страницу
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

# Настраиваем Nginx
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

# Включаем сайт
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# Получаем SSL сертификат
systemctl stop nginx
certbot certonly --standalone --non-interactive --agree-tos \
    --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN

if [[ $? -ne 0 ]]; then
    echo "Ошибка при получении сертификата!"
    exit 1
fi

systemctl start nginx

# Финальная конфигурация с HTTPS
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

# Автообновление сертификата
(crontab -l 2>/dev/null; echo "0 0 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -

echo ""
echo "=========================================="
echo -e "${GREEN}✅ УСТАНОВКА ЗАВЕРШЕНА!${NC}"
echo "=========================================="
echo ""
echo -e "${GREEN}Сайт: https://$DOMAIN${NC}"
echo ""
echo -e "${YELLOW}⚠️  ОТКРОЙ ПОРТЫ В ХОСТИНГЕ:${NC}"
echo "   TCP 80  → HTTP"
echo "   TCP 443 → HTTPS"
echo ""
