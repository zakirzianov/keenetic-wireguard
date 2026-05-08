# Шаг 8: Настройка доступа к локальным ресурсам

## Настройка доступа к локальным ресурсам `Keenetic-LAN` через WG

[ ] Добавить подсеть `Keenetic-LAN` (например, `192.168.1.0/24`) в параметр `AllowedIPs` конфигурации WG-клиентов

**На Ubuntu 24.04 PC (клиент WG):**
```bash
# Отредактировать конфигурацию WireGuard
sudo vi /etc/wireguard/wg0.conf

# В секции [Peer] убедиться, что AllowedIPs включает подсеть Keenetic-LAN:
# AllowedIPs = 10.0.0.0/24, 192.168.1.0/24

# Перезапустить WireGuard для применения изменений
sudo wg-quick down wg0
sudo wg-quick up wg0
```

**На роутере OpenWRT (если используется):**
```bash
# Через SSH на OpenWRT
# Проверить конфигурацию
uci show network.@wireguard_wg0[-1].allowed_ips

# Если нужно добавить подсеть Keenetic-LAN
uci add_list network.@wireguard_wg0[-1].allowed_ips='192.168.1.0/24'
uci commit network
ifdown wg0 && ifup wg0
```

[ ] Настроить правила firewall на роутере Keenetic для разрешения трафика из `WG-LAN` в `Keenetic-LAN`

**Через web-интерфейс Keenetic:**
- Перейти в "Безопасность" → "Межсетевой экран"
- Создать правило для разрешения трафика из WG-LAN в Keenetic-LAN
- Разрешить forward между зонами WireGuard и Home network

**Через SSH на роутере Keenetic:**
```bash
# Подключиться к роутеру
ssh -p 2222 myuser@192.168.1.1

# Разрешить forward из WG в локальную сеть
iptables -A FORWARD -i wg0 -o br0 -j ACCEPT
iptables -A FORWARD -i br0 -o wg0 -m state --state RELATED,ESTABLISHED -j ACCEPT

# Сохранить правила
iptables-save > /etc/firewall.user
```

[ ] Проверить доступ к локальным ресурсам `Keenetic-LAN` из WG-сети (например, ping устройств в локальной сети)

**На Ubuntu 24.04 (с активным WG-соединением):**
```bash
# Проверить ping роутера в локальной сети
ping -c 4 192.168.1.1

# Проверить ping других устройств в локальной сети (если известны IP)
ping -c 4 192.168.1.X
```

**Ожидаемый результат:** Пакеты должны доходить через WG-туннель, 0% потерь

[ ] Создать в `Keenetic-LAN` сервер с фиксированным IP-адресом, например `192.168.1.11` (настроить статический IP или резервирование в DHCP)

**Вариант 1: Статический IP на сервере (Ubuntu 24.04):**
```bash
# На сервере 192.168.1.11
# Отредактировать netplan конфигурацию
sudo vi /etc/netplan/01-netcfg.yaml

# Пример конфигурации:
network:
  version: 2
  renderer: networkd
  ethernets:
    eth0:  # или ваше имя интерфейса
      addresses:
        - 192.168.1.11/24
      routes:
        - to: default
          via: 192.168.1.1
      nameservers:
        addresses:
          - 192.168.1.1
          - 8.8.8.8

# Применить конфигурацию
sudo netplan apply
```

**Вариант 2: Резервирование DHCP на роутере Keenetic:**
- Через web-интерфейс: "Домашняя сеть" → "Устройства"
- Найти устройство по MAC-адресу
- Назначить фиксированный IP 192.168.1.11

[ ] Установить Docker на сервере `192.168.1.11` (если еще не установлен)

**На сервере Ubuntu 24.04:**
```bash
# Обновить пакеты
sudo apt update

# Установить зависимости
sudo apt install -y ca-certificates curl gnupg

# Добавить официальный GPG ключ Docker
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Добавить репозиторий Docker
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Обновить индекс пакетов
sudo apt update

# Установить Docker
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Проверить установку
sudo docker --version
sudo docker compose version

# Добавить текущего пользователя в группу docker (чтобы не использовать sudo)
sudo usermod -aG docker $USER

# Применить изменения (или перелогиниться)
newgrp docker

# Включить автозапуск Docker
sudo systemctl enable docker
```

[ ] Запустить на сервере `192.168.1.11` web-сервер в докер-контейнере на порту, например `9898`

**На сервере 192.168.1.11:**
```bash
# Создать директорию для проекта
mkdir -p ~/test-webserver
cd ~/test-webserver

# Создать простой HTML файл
cat > index.html << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Test Web Server</title>
</head>
<body>
    <h1>Тестовый Web-сервер работает!</h1>
    <p>Сервер: 192.168.1.11:9898</p>
    <p>Этот сервер доступен из локальной сети и через WireGuard VPN.</p>
</body>
</html>
EOF

# Запустить nginx в Docker на порту 9898
docker run -d \
  --name test-webserver \
  --restart unless-stopped \
  -p 9898:80 \
  -v $(pwd)/index.html:/usr/share/nginx/html/index.html:ro \
  nginx:alpine

# Проверить, что контейнер запущен
docker ps | grep test-webserver
```

[ ] Проверить доступ к web-серверу `http://192.168.1.11:9898` из `Keenetic-LAN`

**С любого устройства в локальной сети Keenetic-LAN:**
```bash
# Проверить через curl
curl http://192.168.1.11:9898

# Или открыть в браузере
firefox http://192.168.1.11:9898
```

**Ожидаемый результат:** Должна открыться страница с текстом "Тестовый Web-сервер работает!"

[ ] Проверить доступ к web-серверу `http://192.168.1.11:9898` из `WG-LAN`

**На Ubuntu 24.04 (с активным WG-соединением из внешней сети):**
```bash
# Убедиться, что WireGuard подключен
sudo wg show

# Проверить доступ к web-серверу через VPN
curl http://192.168.1.11:9898

# Или открыть в браузере
firefox http://192.168.1.11:9898
```

**Ожидаемый результат:** Страница должна открыться через VPN-туннель

[ ] Проверить невозможность доступа к web-серверу `http://192.168.1.11:9898` из интернета напрямую

**Из внешней сети (отключив WG, например через мобильный интернет):**
```bash
# Отключить WireGuard
sudo wg-quick down wg0

# Узнать внешний IP роутера (выполнить в локальной сети или знать заранее)
# curl ifconfig.me

# Попробовать подключиться к серверу напрямую (должно не работать)
curl http://192.168.1.11:9898 --max-time 10
```

**Ожидаемый результат:** Соединение должно истекать по таймауту или быть отклонено (сервер находится во внутренней сети и недоступен напрямую из интернета)
