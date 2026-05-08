# Шаг 9: Настройка локального сервера

## Создание поддоменного имени для локального сервера

[ ] Включить компонент "DNS-сервер" на роутере Keenetic (если еще не включен)

**Через web-интерфейс Keenetic:**
- Перейти в "Система" → "Компоненты"
- Найти компонент "DNS-сервер" или "Dnsmasq"
- Установить/включить компонент
- Дождаться завершения установки

**Через SSH на роутере Keenetic:**
```bash
# Подключиться к роутеру
ssh -p 2222 myuser@192.168.1.1

# Установить компонент DNS
system component install dns-server
```

[ ] Добавить DNS-запись на роутере Keenetic для разрешения имени `srvok.ckox` в `192.168.1.11`

**Через web-интерфейс Keenetic:**
- Перейти в "Домашняя сеть" → "DNS"
- Добавить локальную DNS-запись:
  - Имя: `srvok.ckox`
  - IP-адрес: `192.168.1.11`
- Сохранить

**Через SSH на роутере Keenetic:**
```bash
# Подключиться к роутеру
ssh -p 2222 myuser@192.168.1.1

# Добавить запись в hosts-файл Dnsmasq
echo "192.168.1.11 srvok.ckox" >> /etc/hosts

# Или создать отдельный файл для dnsmasq
echo "address=/srvok.ckox/192.168.1.11" > /etc/dnsmasq.d/local-domains.conf

# Перезапустить DNS-сервер
/etc/init.d/dnsmasq restart
```

[ ] Настроить WG-клиенты на использование DNS-сервера Keenetic

**На Ubuntu 24.04 (клиент WG):**
```bash
# Отредактировать конфигурацию WireGuard
sudo vi /etc/wireguard/wg0.conf

# В секции [Interface] добавить или проверить строку DNS:
DNS = 192.168.1.1

# Перезапустить WireGuard
sudo wg-quick down wg0
sudo wg-quick up wg0
```

**Проверка DNS в конфигурации:**
```bash
# Проверить, что DNS настроен
sudo wg-quick up wg0
# Посмотреть resolv.conf
cat /etc/resolv.conf
```

[ ] Проверить разрешение имени `srvok.ckox` из `Keenetic-LAN`

**С любого устройства в Keenetic-LAN:**
```bash
# Проверить разрешение DNS
nslookup srvok.ckox
# или
dig srvok.ckox
# или
ping -c 2 srvok.ckox
```

**Ожидаемый результат:** Должен вернуться IP `192.168.1.11`

[ ] Проверить разрешение имени `srvok.ckox` из `WG-LAN`

**На Ubuntu 24.04 (с активным WG-соединением):**
```bash
# Проверить разрешение DNS через WG
nslookup srvok.ckox
ping -c 2 srvok.ckox
```

**Ожидаемый результат:** Должен разрешаться в `192.168.1.11`

[ ] Проверить доступ к web-серверу `http://srvok.ckox:9898` из `Keenetic-LAN`

```bash
curl http://srvok.ckox:9898
# Или в браузере
firefox http://srvok.ckox:9898
```

[ ] Проверить доступ к web-серверу `http://srvok.ckox:9898` из `WG-LAN`

```bash
# С активным WG-соединением
curl http://srvok.ckox:9898
```

[ ] Проверить невозможность доступа к web-серверу `http://srvok.ckox:9898` из интернета напрямую

**Ожидаемый результат:** Доменное имя не разрешается (локальный DNS), доступ невозможен

[ ] Выбрать и установить обратный прокси-сервер на `192.168.1.11` (nginx, Caddy, Traefik)

**📁 Готовые конфигурации доступны в папке [`examples/`](../examples/)**

- [Caddy (рекомендуется)](../examples/caddy/) - простая автоматизированная настройка
- [Nginx (альтернатива)](../examples/nginx/) - более гибкая конфигурация

**Вариант 1: Caddy (рекомендуется для простоты) в Docker:**

**На сервере 192.168.1.11:**
```bash
# Создать директорию для Caddy
mkdir -p ~/caddy
cd ~/caddy

# Создать Caddyfile
cat > Caddyfile << 'EOF'
# Базовая конфигурация для проксирования на порт 9898
srvok.ckox {
    reverse_proxy localhost:9898
}
EOF

# Создать docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - caddy_config:/config
    network_mode: host

volumes:
  caddy_data:
  caddy_config:
EOF

# Запустить Caddy
docker compose up -d

# Проверить логи
docker compose logs -f caddy
```

**Вариант 2: Nginx в Docker:**

```bash
# Создать директорию для Nginx
mkdir -p ~/nginx/conf
cd ~/nginx

# Создать конфигурацию nginx
cat > conf/default.conf << 'EOF'
server {
    listen 80;
    server_name srvok.ckox;

    location / {
        proxy_pass http://host.docker.internal:9898;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Создать docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  nginx:
    image: nginx:alpine
    container_name: nginx-proxy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./conf:/etc/nginx/conf.d:ro
    extra_hosts:
      - "host.docker.internal:host-gateway"
EOF

# Запустить Nginx
docker compose up -d
```

[ ] Настроить прокси-сервер для проксирования запросов с порта `80` на локальный порт `9898`

**Уже настроено в предыдущем шаге через Caddyfile или nginx.conf**

[ ] Проверить доступ к web-серверу `http://srvok.ckox` из `Keenetic-LAN`

```bash
curl http://srvok.ckox
firefox http://srvok.ckox
```

**Ожидаемый результат:** Страница открывается без указания порта

[ ] Проверить доступ к web-серверу `http://srvok.ckox` из `WG-LAN`

```bash
# С активным WG
curl http://srvok.ckox
```

[ ] Настроить firewall сервера чтобы web-сервер `srvok.ckox` был доступен из интернета через `WG`

**На сервере 192.168.1.11:**
```bash
# Проверить статус UFW
sudo ufw status

# Если firewall включен, разрешить порты 80 и 443
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Или разрешить только из определенных сетей
sudo ufw allow from 10.0.0.0/24 to any port 80
sudo ufw allow from 10.0.0.0/24 to any port 443
sudo ufw allow from 192.168.1.0/24 to any port 80
sudo ufw allow from 192.168.1.0/24 to any port 443
```

[ ] Проверить доступ к web-серверу `http://srvok.ckox` из интернета через `WG`

```bash
# С активным WG-соединением из внешней сети
curl http://srvok.ckox
```

## Добавление SSL сертификата

[ ] Установить `mkcert` на сервере `192.168.1.11`

**На сервере Ubuntu 24.04:**
```bash
# Установить зависимости
sudo apt update
sudo apt install -y libnss3-tools

# Скачать mkcert
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Проверить установку
mkcert --version
```

[ ] Создать локальный CA: `mkcert -install`

**На сервере 192.168.1.11:**
```bash
# Создать локальный CA
mkcert -install

# Посмотреть где находится rootCA
mkcert -CAROOT
```

[ ] Сгенерировать wildcard SSL сертификат для доменного имени `*.srvok.ckox`

**На сервере 192.168.1.11:**
```bash
# Перейти в директорию прокси-сервера
cd ~/caddy  # или ~/nginx

# Создать директорию для сертификатов
mkdir -p certs
cd certs

# Сгенерировать сертификаты
mkcert "*.srvok.ckox" "srvok.ckox"

# Переименовать для удобства
mv _wildcard.srvok.ckox+1.pem srvok.ckox.crt
mv _wildcard.srvok.ckox+1-key.pem srvok.ckox.key

# Установить правильные права
chmod 644 srvok.ckox.crt
chmod 600 srvok.ckox.key
```

[ ] Скопировать корневой CA-сертификат mkcert с сервера

**На сервере 192.168.1.11:**
```bash
# Узнать путь к CA
CAROOT=$(mkcert -CAROOT)
echo "CA находится в: $CAROOT"

# Скопировать на клиент (выполнить на клиенте)
scp user@192.168.1.11:~/.local/share/mkcert/rootCA.pem ./mkcert-rootCA.pem
```

[ ] Установить корневой CA-сертификат в доверенные на всех клиентских устройствах

**На Ubuntu 24.04 (клиент):**
```bash
# Копировать сертификат в систему
sudo cp mkcert-rootCA.pem /usr/local/share/ca-certificates/mkcert-rootCA.crt

# Обновить список сертификатов
sudo update-ca-certificates

# Для Firefox (дополнительно)
# Открыть Firefox → Settings → Privacy & Security → Certificates → View Certificates
# Импортировать mkcert-rootCA.pem в раздел "Authorities"
```

[ ] Настроить прокси-сервер на использование сгенерированных SSL-сертификатов

**Для Caddy - обновить Caddyfile:**
```bash
cd ~/caddy

cat > Caddyfile << 'EOF'
srvok.ckox {
    tls /data/certs/srvok.ckox.crt /data/certs/srvok.ckox.key
    reverse_proxy localhost:9898
}
EOF

# Обновить docker-compose.yml для монтирования сертификатов
cat > docker-compose.yml << 'EOF'
version: '3'
services:
  caddy:
    image: caddy:alpine
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - ./certs:/data/certs:ro
      - caddy_data:/data
      - caddy_config:/config
    network_mode: host

volumes:
  caddy_data:
  caddy_config:
EOF

# Перезапустить Caddy
docker compose down
docker compose up -d
```

[ ] Настроить прокси-сервер на автоматическое перенаправление HTTP → HTTPS

**Для Caddy (автоматически):** Caddy делает это по умолчанию

**Для Nginx - обновить конфигурацию:**
```nginx
server {
    listen 80;
    server_name srvok.ckox;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl;
    server_name srvok.ckox;

    ssl_certificate /etc/nginx/certs/srvok.ckox.crt;
    ssl_certificate_key /etc/nginx/certs/srvok.ckox.key;

    location / {
        proxy_pass http://host.docker.internal:9898;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

[ ] Проверить, что при обращении к `http://srvok.ckox` происходит перенаправление на `https://srvok.ckox`

```bash
curl -I http://srvok.ckox
# Должен вернуться код 301 или 308 с Location: https://srvok.ckox
```

[ ] Проверить доступ к `https://srvok.ckox` из `Keenetic-LAN` (без предупреждений)

```bash
curl https://srvok.ckox
firefox https://srvok.ckox
```

**Ожидаемый результат:** Браузер не показывает предупреждения о сертификате

[ ] Проверить доступ к `https://srvok.ckox` из `WG-LAN` (без предупреждений)

```bash
# С активным WG
curl https://srvok.ckox
```

## Добавление ссылок на другие локальные ресурсы

[ ] Добавить wildcard DNS-запись `*.srvok.ckox` → `192.168.1.11` на роутере Keenetic

**Через web-интерфейс Keenetic:**
- Добавить DNS-запись:
  - Имя: `*.srvok.ckox`
  - IP: `192.168.1.11`

**Через SSH:**
```bash
ssh -p 2222 myuser@192.168.1.1
echo "address=/.srvok.ckox/192.168.1.11" >> /etc/dnsmasq.d/local-domains.conf
/etc/init.d/dnsmasq restart
```

[ ] Настроить прокси-сервер для маршрутизации поддомена `keenetic.srvok.ckox`

**Обновить Caddyfile:**
```bash
cd ~/caddy

cat > Caddyfile << 'EOF'
srvok.ckox {
    tls /data/certs/srvok.ckox.crt /data/certs/srvok.ckox.key
    reverse_proxy localhost:9898
}

keenetic.srvok.ckox {
    tls /data/certs/srvok.ckox.crt /data/certs/srvok.ckox.key
    reverse_proxy https://192.168.1.1 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}
EOF

docker compose restart
```

[ ] Добавить на главную страницу web-сервера `srvok.ckox` ссылку на роутер

**Обновить index.html:**
```bash
cd ~/test-webserver

cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Локальные сервисы</title>
</head>
<body>
    <h1>Локальные сервисы</h1>
    <ul>
        <li><a href="https://keenetic.srvok.ckox">Роутер Keenetic</a></li>
    </ul>
</body>
</html>
EOF

docker restart test-webserver
```

[ ] Проверить разрешение DNS для `keenetic.srvok.ckox`

```bash
nslookup keenetic.srvok.ckox
# Должен вернуть 192.168.1.11
```

[ ] Проверить доступ к `https://keenetic.srvok.ckox` из `Keenetic-LAN` и `WG-LAN`

```bash
curl -k https://keenetic.srvok.ckox
firefox https://keenetic.srvok.ckox
```

[ ] Создать еще один web-сервис в докер-контейнере на порту `9191`

```bash
mkdir -p ~/nas-service
cd ~/nas-service

cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head><title>NAS Service</title></head>
<body><h1>NAS Service работает!</h1></body>
</html>
EOF

docker run -d \
  --name nas-service \
  --restart unless-stopped \
  -p 9191:80 \
  -v $(pwd)/index.html:/usr/share/nginx/html/index.html:ro \
  nginx:alpine
```

[ ] Настроить прокси для `nas.srvok.ckox`

**Добавить в Caddyfile:**
```
nas.srvok.ckox {
    tls /data/certs/srvok.ckox.crt /data/certs/srvok.ckox.key
    reverse_proxy localhost:9191
}
```

[ ] Проверить доступ к `https://nas.srvok.ckox`

```bash
curl https://nas.srvok.ckox
firefox https://nas.srvok.ckox
```

[ ] Проверить невозможность доступа к `https://nas.srvok.ckox` из интернета напрямую

**Ожидаемый результат:** Доступ возможен только через WG-туннель
