# Шаг 6: Настройка WG клиента на PC

## Настройка клиента WG

### Настройка клиента WG на PC

[ ] Установить клиент WireGuard на PC (для Windows/macOS/Linux)

**На Ubuntu 24.04:**
```bash
# Установить WireGuard
sudo apt update
sudo apt install -y wireguard wireguard-tools

# Проверить установку
wg --version
```

[ ] Сгенерировать пару ключей для клиента: `wg genkey | tee privatekey | wg pubkey > publickey`

**На Ubuntu 24.04:**
```bash
# Создать директорию для конфигурации (если не существует)
sudo mkdir -p /etc/wireguard
cd /etc/wireguard

# Сгенерировать приватный и публичный ключи для клиента
wg genkey | sudo tee client_privatekey | wg pubkey | sudo tee client_publickey

# Посмотреть ключи
echo "Client Private Key:"
sudo cat client_privatekey
echo "Client Public Key:"
sudo cat client_publickey

# Установить правильные права
sudo chmod 600 client_privatekey
sudo chmod 644 client_publickey
```

**⚠️ ВАЖНО:** Сохраните публичный ключ - он понадобится для добавления на сервер Keenetic!

[ ] Добавить публичный ключ клиента в конфигурацию сервера WG на роутере Keenetic

**Через web-интерфейс роутера Keenetic:**
- Перейти в "Интернет" → "WireGuard" → выбрать интерфейс `wg0`
- Нажать "Добавить пир"
- Указать:
  - Публичный ключ: (вставить содержимое `client_publickey` с Ubuntu PC)
  - AllowedIPs: `10.0.0.2/32`
  - PersistentKeepalive: `25`
- Сохранить

**Через SSH на роутере Keenetic:**
```bash
# Подключиться к роутеру
ssh -p 2222 myuser@192.168.1.1

# Добавить peer в конфигурацию
cat >> /opt/etc/wireguard/wg0.conf << 'EOF'

[Peer]
# PC Client
PublicKey = ВСТАВИТЬ_CLIENT_PUBLIC_KEY_С_PC
AllowedIPs = 10.0.0.2/32
PersistentKeepalive = 25
EOF

# Перезапустить WireGuard для применения изменений
wg-quick down wg0
wg-quick up wg0
```

[ ] Создать конфигурационный файл клиента `.conf` (указать приватный ключ клиента, публичный ключ сервера, IP-адрес клиента в WG-LAN, endpoint сервера, AllowedIPs)

**На Ubuntu 24.04:**
```bash
# Узнать внешний IP роутера Keenetic (выполнить на роутере или в локальной сети)
curl ifconfig.me

# Создать конфигурационный файл клиента
sudo cat > /etc/wireguard/wg0.conf << 'EOF'
[Interface]
PrivateKey = ВСТАВИТЬ_CLIENT_PRIVATE_KEY_С_PC
Address = 10.0.0.2/24
DNS = 192.168.1.1

[Peer]
PublicKey = ВСТАВИТЬ_SERVER_PUBLIC_KEY_С_KEENETIC
PresharedKey = ВСТАВИТЬ_PRESHARED_KEY_ЕСЛИ_ИСПОЛЬЗОВАЛИ
Endpoint = ВНЕШНИЙ_IP_РОУТЕРА:51820
AllowedIPs = 10.0.0.0/24, 192.168.1.0/24
PersistentKeepalive = 25
EOF

# Установить правильные права
sudo chmod 600 /etc/wireguard/wg0.conf
```

**Пояснение параметров:**
- `Address` - IP-адрес клиента в WG-сети
- `DNS` - DNS-сервер (роутер Keenetic) для разрешения локальных имён
- `Endpoint` - внешний IP и порт роутера Keenetic
- `AllowedIPs` - подсети, трафик к которым будет идти через VPN (WG-LAN + Keenetic-LAN)
- `PersistentKeepalive` - поддержание соединения для NAT traversal

[ ] Импортировать конфигурацию в клиент WireGuard на PC

**На Ubuntu 24.04 (конфигурация уже создана выше):**
Файл уже находится в `/etc/wireguard/wg0.conf`, дополнительный импорт не требуется.

[ ] Запустить WireGuard-соединение на клиенте

**На Ubuntu 24.04:**
```bash
# Запустить WireGuard интерфейс
sudo wg-quick up wg0

# Проверить статус
sudo wg show

# Добавить в автозагрузку
sudo systemctl enable wg-quick@wg0
```

**Остановить WireGuard:**
```bash
sudo wg-quick down wg0
```

[ ] Проверить подключение клиента к серверу WG (проверить статус соединения, handshake)

**На Ubuntu 24.04:**
```bash
# Проверить статус WireGuard
sudo wg show

# Проверить наличие handshake (должна быть недавняя метка времени)
sudo wg show wg0 latest-handshakes

# Проверить интерфейс
ip addr show wg0
```

**Ожидаемый результат:**
- Интерфейс `wg0` должен быть активен с IP `10.0.0.2`
- В выводе `wg show` должен быть виден peer (сервер) с последним handshake
- `latest handshakes` не должен быть старше 2-3 минут

[ ] Проверить ping роутера Keenetic из WG-сети (по IP в Keenetic-LAN)

**На Ubuntu 24.04 (с активным WG-соединением):**
```bash
# Проверить ping роутера по IP в локальной сети
ping -c 4 192.168.1.1
```

**Ожидаемый результат:** Пакеты должны доходить через WG-туннель, 0% потерь

[ ] Проверить доступ к web-интерфейсу роутера из интернета через WG

**На Ubuntu 24.04 (с активным WG-соединением, из любой внешней сети):**
```bash
# Проверить доступ к web-интерфейсу роутера через WG-туннель
curl -I http://192.168.1.1

# Открыть в браузере
firefox http://192.168.1.1
```

**Ожидаемый результат:** Доступ должен быть разрешён через VPN-туннель

[ ] Проверить доступ по `ssh` из WG-сети

**На Ubuntu 24.04 (с активным WG-соединением):**
```bash
# Подключиться по SSH к роутеру через WG-туннель
ssh -p 2222 myuser@192.168.1.1

# Проверить, что подключение идёт через WG
# На роутере выполнить:
who

# Выйти
exit
```

**Ожидаемый результат:** SSH-соединение должно успешно установиться через VPN

