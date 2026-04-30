#!/bin/bash
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

if [[ $EUID -ne 0 ]]; then
    echo "Запусти с sudo!"
    exit 1
fi

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
        
        cat > /var/www/$DOMAIN/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Сервер работает</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        .logo {
            font-size: 6rem;
            margin-bottom: 1rem;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        .status {
            background: rgba(255,255,255,0.2);
            border-radius: 50px;
            padding: 0.5rem 1.5rem;
            display: inline-block;
            margin: 1rem 0;
            backdrop-filter: blur(10px);
        }
        .status-dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            background: #4ade80;
            border-radius: 50%;
            margin-right: 8px;
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .message {
            font-size: 1.2rem;
            margin: 2rem 0;
            opacity: 0.9;
        }
        .info {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 1rem;
            margin-top: 2rem;
            font-size: 0.9rem;
        }
        .info h3 {
            margin-bottom: 0.5rem;
        }
        .info p {
            margin: 0.3rem 0;
        }
        .footer {
            margin-top: 3rem;
            font-size: 0.8rem;
            opacity: 0.7;
        }
        @media (max-width: 768px) {
            h1 { font-size: 2rem; }
            .logo { font-size: 4rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>Всё работает!</h1>
        <div class="status">
            <span class="status-dot"></span>
            Сервер успешно запущен
        </div>
        <div class="message">
            Ваш сайт настроен и готов к работе
        </div>
        <div class="info">
            <h3>📋 Информация</h3>
            <p>✅ SSL сертификат установлен</p>
            <p>✅ HTTPS работает корректно</p>
            <p>✅ Сервер в онлайн режиме</p>
        </div>
        <div class="footer">
            Powered by Nginx + Let's Encrypt
        </div>
    </div>
</body>
</html>
EOF
        
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
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА"
        echo "💡 Команда для открытия портов: sudo ufw allow 80,443/tcp"
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
        echo -e "${YELLOW}💡 Посмотри выше порт панели и выполни:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ПАНЕЛИ/tcp${NC}"
        echo ""
        echo -e "${RED}⚠️ ДЛЯ КАЖДОГО ИНБАУНДА ТОЖЕ НУЖНО ОТКРЫВАТЬ ПОРТЫ!${NC}"
        echo -e "${YELLOW}💡 Когда добавишь инбаунд, открой его порт:${NC}"
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
        echo -e "${YELLOW}💡 Посмотри выше порт панели и выполни:${NC}"
        echo -e "${GREEN}   sudo ufw allow ПОРТ_ПАНЕЛИ/tcp${NC}"
        echo ""
        echo -e "${RED}⚠️ ДЛЯ КАЖДОГО ИНБАУНДА ТОЖЕ НУЖНО ОТКРЫВАТЬ ПОРТЫ!${NC}"
        echo -e "${YELLOW}💡 Когда добавишь инбаунд, открой его порт:${NC}"
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
        
        cat > /var/www/$DOMAIN/html/index.html <<'EOF'
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Сервер работает</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, 'Helvetica Neue', Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        .logo {
            font-size: 6rem;
            margin-bottom: 1rem;
            animation: pulse 2s infinite;
        }
        @keyframes pulse {
            0% { transform: scale(1); }
            50% { transform: scale(1.1); }
            100% { transform: scale(1); }
        }
        h1 {
            font-size: 3rem;
            margin-bottom: 1rem;
            font-weight: 700;
        }
        .status {
            background: rgba(255,255,255,0.2);
            border-radius: 50px;
            padding: 0.5rem 1.5rem;
            display: inline-block;
            margin: 1rem 0;
            backdrop-filter: blur(10px);
        }
        .status-dot {
            display: inline-block;
            width: 10px;
            height: 10px;
            background: #4ade80;
            border-radius: 50%;
            margin-right: 8px;
            animation: blink 1s infinite;
        }
        @keyframes blink {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        .message {
            font-size: 1.2rem;
            margin: 2rem 0;
            opacity: 0.9;
        }
        .info {
            background: rgba(0,0,0,0.2);
            border-radius: 10px;
            padding: 1rem;
            margin-top: 2rem;
            font-size: 0.9rem;
        }
        .info h3 {
            margin-bottom: 0.5rem;
        }
        .info p {
            margin: 0.3rem 0;
        }
        .footer {
            margin-top: 3rem;
            font-size: 0.8rem;
            opacity: 0.7;
        }
        @media (max-width: 768px) {
            h1 { font-size: 2rem; }
            .logo { font-size: 4rem; }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">🚀</div>
        <h1>Всё работает!</h1>
        <div class="status">
            <span class="status-dot"></span>
            Сервер успешно запущен
        </div>
        <div class="message">
            Ваш сайт настроен и готов к работе
        </div>
        <div class="info">
            <h3>📋 Информация</h3>
            <p>✅ SSL сертификат установлен</p>
            <p>✅ HTTPS работает корректно</p>
            <p>✅ Сервер в онлайн режиме</p>
        </div>
        <div class="footer">
            Powered by Nginx + Let's Encrypt
        </div>
    </div>
</body>
</html>
EOF
        
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
        echo "⚠️ ОТКРОЙ ПОРТЫ В ФАЕРВОЛЕ ХОСТИНГА"
        echo "💡 Команда для открытия портов: sudo ufw allow 80,443/tcp"
        echo ""
        ;;
    
    4)
        read -p "Введи имя службы (например: mybot, test, app): " SERVICE_NAME
        if [[ -z "$SERVICE_NAME" ]]; then
            SERVICE_NAME="mybot"
        fi
        
        SERVICE_NAME=$(echo "$SERVICE_NAME" | tr ' ' '_' | tr -cd 'a-zA-Z0-9_-')
        
        mkdir -p /my_bots/$SERVICE_NAME
        cd /my_bots/$SERVICE_NAME
        
        echo ""
        echo -e "${YELLOW}📝 Введи код Python скрипта (Enter - будет использован простой скрипт):${NC}"
        echo -e "${BLUE}💡 Когда закончишь писать, нажми Ctrl+D${NC}"
        echo ""
        
        read -r -d '' DEFAULT_SCRIPT <<'EOF'
import time
import datetime

def main():
    print(f"Бот {SERVICE_NAME} запущен: {datetime.datetime.now()}")
    while True:
        print(f"{SERVICE_NAME}: Работаю... {datetime.datetime.now()}")
        time.sleep(60)

if __name__ == "__main__":
    main()
EOF
        
        DEFAULT_SCRIPT=$(echo "$DEFAULT_SCRIPT" | sed "s/{SERVICE_NAME}/$SERVICE_NAME/g")
        
        TEMP_FILE=$(mktemp)
        cat > "$TEMP_FILE"
        SCRIPT_CONTENT=$(cat "$TEMP_FILE")
        rm -f "$TEMP_FILE"
        
        if [[ -z "$SCRIPT_CONTENT" ]]; then
            echo "$DEFAULT_SCRIPT" > main.py
            echo -e "${GREEN}✅ Использован стандартный скрипт${NC}"
            NEED_PIP=false
        else
            echo "$SCRIPT_CONTENT" > main.py
            echo -e "${GREEN}✅ Твой скрипт сохранен${NC}"
            
            echo ""
            echo -e "${YELLOW}📦 Какие библиотеки использует твой скрипт?${NC}"
            echo -e "${BLUE}💡 Введи названия через пробел (например: aiogram pycryptodome requests)${NC}"
            echo -e "${BLUE}💡 Если библиотеки не нужны, просто нажми Enter${NC}"
            echo ""
            read -p "Библиотеки: " LIBRARIES
            
            if [[ -n "$LIBRARIES" ]]; then
                NEED_PIP=true
                PIP_PACKAGES="$LIBRARIES"
            else
                NEED_PIP=false
            fi
        fi
        
        apt update -y
        apt install -y python3.12-venv python3-pip
        
        python3 -m venv venv
        source venv/bin/activate
        
        if [[ "$NEED_PIP" == true ]]; then
            echo -e "${YELLOW}📦 Устанавливаю библиотеки:${NC} $PIP_PACKAGES"
            pip install $PIP_PACKAGES
            echo -e "${GREEN}✅ Библиотеки установлены${NC}"
        fi
        
        cat > /etc/systemd/system/$SERVICE_NAME.service <<EOF
[Unit]
Description=$SERVICE_NAME
After=syslog.target
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/my_bots/$SERVICE_NAME/
ExecStart=/my_bots/$SERVICE_NAME/venv/bin/python3 /my_bots/$SERVICE_NAME/main.py
RestartSec=10
Restart=always

[Install]
WantedBy=multi-user.target
EOF
        
        systemctl daemon-reload
        systemctl enable $SERVICE_NAME
        systemctl start $SERVICE_NAME
        
        echo ""
        echo -e "${GREEN}✅ Python скрипт '$SERVICE_NAME' установлен и запущен${NC}"
        echo -e "${YELLOW}📁 Папка:${NC} /my_bots/$SERVICE_NAME/"
        echo -e "${YELLOW}📄 Файл:${NC} main.py"
        if [[ "$NEED_PIP" == true ]]; then
            echo -e "${YELLOW}📦 Установленные библиотеки:${NC} $PIP_PACKAGES"
        fi
        echo ""
        echo -e "${BLUE}🔧 Управление скриптом:${NC}"
        echo -e "   💡 Остановить:     ${GREEN}systemctl stop $SERVICE_NAME${NC}"
        echo -e "   💡 Запустить:      ${GREEN}systemctl start $SERVICE_NAME${NC}"
        echo -e "   💡 Перезапустить:  ${GREEN}systemctl restart $SERVICE_NAME${NC}"
        echo -e "   💡 Статус:         ${GREEN}systemctl status $SERVICE_NAME${NC}"
        echo -e "   💡 Логи:           ${GREEN}journalctl -u $SERVICE_NAME -f${NC}"
        echo ""
        echo -e "${YELLOW}⚠️ Редактирование:${NC} nano /my_bots/$SERVICE_NAME/main.py"
        echo -e "${YELLOW}⚠️ После изменений:${NC} systemctl restart $SERVICE_NAME"
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
        echo "✅ Fail2ban установлен и настроен"
        echo "📝 Максимум попыток: 3"
        echo "⏱️ Время бана: навсегда"
        echo ""
        echo "🔧 Управление:"
        echo "💡 Посмотреть забаненных: fail2ban-client status sshd"
        echo "💡 Разбанить IP: fail2ban-client set sshd unbanip IP"
        echo "💡 Статус: systemctl status fail2ban"
        echo ""
        ;;
    
    *)
        echo "Неверный выбор"
        exit 1
        ;;
esac
