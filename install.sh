#!/bin/bash

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Функции
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
    echo "Команда: sudo bash $0"
    exit 1
fi

# Очистка экрана и приветствие
clear
print_header "🚀 Установка Nginx + SSL"

# ЗАПРОС ДОМЕНА
echo ""
print_info "Для получения SSL сертификата нужен домен, направленный на этот сервер"
echo ""
echo -n "Введи домен (например: site.ru): "
read DOMAIN

# Проверка что домен ввели
if [[ -z "$DOMAIN" ]]; then
    print_error "Домен не введён!"
    exit 1
fi

print_ok "Домен: $DOMAIN"
print_info "Начинаю установку..."

# Установка пакетов
apt update -y
apt install -y nginx certbot python3-certbot-nginx

# Создание директории и тестовой страницы
mkdir -p /var/www/$DOMAIN/html
cat > /var/www/$DOMAIN/html/index.html <<EOF
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$DOMAIN - Сайт работает</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            text-align: center;
            padding: 50px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            height: 100vh;
            margin: 0;
            display: flex;
            justify-content: center;
            align-items: center;
        }
        .container {
            background: rgba(255,255,255,0.1);
            padding: 40px;
            border-radius: 20px;
        }
        h1 { font-size: 48px; margin-bottom: 20px; }
        p { font-size: 20px; }
        .domain { color: #ffd700; font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>✅ Сайт работает!</h1>
        <p>SSL сертификат активен для <span class="domain">$DOMAIN</span></p>
        <p>🔒 Соединение защищено</p>
    </div>
</body>
</html>
EOF

# Временная конфигурация Nginx для получения сертификата
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

# Включение сайта
ln -sf /etc/nginx/sites-available/$DOMAIN /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
systemctl restart nginx

# Получение SSL сертификата
print_info "Получаю SSL сертификат для $DOMAIN..."
systemctl stop nginx

certbot certonly --standalone --non-interactive --agree-tos \
    --email admin@$DOMAIN --domains $DOMAIN --domains www.$DOMAIN

if [[ $? -ne 0 ]]; then
    print_error "Ошибка при получении сертификата!"
    print_warn "Проверь что домен $DOMAIN направлен на IP этого сервера"
    print_warn "И что порты 80 и 443 открыты"
    exit 1
fi

print_ok "Сертификат получен!"
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

# Финальный вывод
clear
print_header "✅ УСТАНОВКА ЗАВЕРШЕНА!"
echo ""
print_ok "Твой сайт: https://$DOMAIN"
echo ""
print_warn "⚠️  ВАЖНО! Открой порты в панели хостинга:"
echo ""
echo "   ┌─────────────────────────────────────┐"
echo "   │  TCP 80    → HTTP (для сертификата) │"
echo "   │  TCP 443   → HTTPS (сам сайт)       │"
echo "   └─────────────────────────────────────┘"
echo ""
print_info "Сертификат будет обновляться автоматически каждую ночь"
echo ""
