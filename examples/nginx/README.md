# Nginx Reverse Proxy Configuration

Альтернативная конфигурация Nginx в качестве обратного прокси-сервера для локальных сервисов.

## Требования

- Docker и Docker Compose
- Сгенерированные SSL-сертификаты (mkcert)
- Сервер с IP 192.168.1.11

## Установка

### 1. Скопировать файлы на сервер

```bash
# На сервере 192.168.1.11
mkdir -p ~/nginx
cd ~/nginx

# Скопировать default.conf и docker-compose.yml из репозитория
```

### 2. Создать директорию для сертификатов

```bash
mkdir -p ~/nginx/certs
cd ~/nginx/certs
```

### 3. Сгенерировать SSL-сертификаты с mkcert

```bash
# Установить mkcert (если еще не установлен)
sudo apt install libnss3-tools
curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
chmod +x mkcert-v*-linux-amd64
sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert

# Создать локальный CA
mkcert -install

# Сгенерировать wildcard сертификат
mkcert "*.srvok.ckox" "srvok.ckox"

# Переименовать файлы
mv _wildcard.srvok.ckox+1.pem srvok.ckox.crt
mv _wildcard.srvok.ckox+1-key.pem srvok.ckox.key

# Установить права
chmod 644 srvok.ckox.crt
chmod 600 srvok.ckox.key
```

### 4. Настроить default.conf под свою сеть

Отредактируйте `default.conf` и измените:
- IP-адреса сервисов
- Доменные имена
- Порты

### 5. Запустить Nginx

```bash
cd ~/nginx
docker compose up -d
```

### 6. Проверить логи

```bash
docker compose logs -f nginx
```

## Структура файлов

```
~/nginx/
├── default.conf             # Конфигурация Nginx
├── docker-compose.yml       # Docker Compose файл
└── certs/                   # Директория с SSL-сертификатами
    ├── srvok.ckox.crt      # Публичный сертификат
    └── srvok.ckox.key      # Приватный ключ
```

## Доступные сервисы

После запуска будут доступны следующие сервисы:

- `https://srvok.ckox` - главный сервис (порт 9898)
- `https://keenetic.srvok.ckox` - веб-интерфейс роутера
- `https://nas.srvok.ckox` - NAS сервис (порт 9191)

HTTP запросы автоматически перенаправляются на HTTPS.

## Управление

```bash
# Запустить
docker compose up -d

# Остановить
docker compose down

# Перезапустить
docker compose restart

# Просмотр логов
docker compose logs -f nginx

# Перезагрузить конфигурацию
docker compose exec nginx nginx -s reload
```

## Проверка конфигурации

```bash
# Проверить синтаксис конфигурации перед применением
docker compose exec nginx nginx -t
```

## Установка корневого CA на клиентах

**На Ubuntu 24.04:**
```bash
# Скопировать CA с сервера
scp user@192.168.1.11:~/.local/share/mkcert/rootCA.pem ./mkcert-rootCA.pem

# Установить в систему
sudo cp mkcert-rootCA.pem /usr/local/share/ca-certificates/mkcert-rootCA.crt
sudo update-ca-certificates
```

**Для Firefox:**
- Settings → Privacy & Security → Certificates → View Certificates
- Импортировать `mkcert-rootCA.pem` в раздел "Authorities"

## Отличия от Caddy

- Требуется явная настройка HTTP → HTTPS редиректов
- Более детальная конфигурация proxy headers
- Необходимость использования `extra_hosts` для доступа к хост-машине
- Более сложная конфигурация, но больше контроля
