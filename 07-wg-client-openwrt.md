# Шаг 7: Настройка WG клиента на OpenWRT

### Настройка клиента WG на роутере с `OpenWRT`

[ ] Создать резервную копию настроек роутера

**Через web-интерфейс OpenWRT (LuCI):**
- Открыть web-интерфейс OpenWRT (обычно `http://192.168.99.1` или другой IP)
- Перейти в "System" → "Backup / Flash Firmware"
- Нажать "Generate archive" для создания резервной копии
- Сохранить файл `.tar.gz` на локальный компьютер с указанием даты

**Через SSH:**
```bash
# Подключиться к роутеру OpenWRT
ssh root@192.168.99.1

# Создать резервную копию конфигурации
sysupgrade -b /tmp/backup-openwrt-$(date +%Y-%m-%d).tar.gz

# Скачать на PC через SCP
# (выполнить с PC)
scp root@192.168.99.1:/tmp/backup-openwrt-$(date +%Y-%m-%d).tar.gz ./
```

[ ] Подключиться к роутеру OpenWRT по SSH

**С Ubuntu 24.04:**
```bash
# Подключиться к роутеру OpenWRT
ssh root@192.168.99.1

# Если используется нестандартный порт
ssh -p PORT root@192.168.99.1
```

[ ] Обновить списки пакетов: `opkg update`

**На роутере OpenWRT через SSH:**
```bash
# Обновить списки пакетов
opkg update
```

[ ] Установить пакеты WireGuard: `opkg install wireguard-tools luci-proto-wireguard kmod-wireguard`

**На роутере OpenWRT через SSH:**
```bash
# Установить WireGuard и его зависимости
opkg install wireguard-tools luci-proto-wireguard kmod-wireguard

# Проверить установку
wg --version
```

[ ] Сгенерировать пару ключей для клиента OpenWRT: `wg genkey | tee privatekey | wg pubkey > publickey`

**На роутере OpenWRT через SSH:**
```bash
# Создать директорию для ключей (если не существует)
mkdir -p /etc/wireguard
cd /etc/wireguard

# Сгенерировать приватный и публичный ключи для клиента OpenWRT
wg genkey | tee openwrt_privatekey | wg pubkey > openwrt_publickey

# Посмотреть ключи
echo "OpenWRT Client Private Key:"
cat openwrt_privatekey
echo "OpenWRT Client Public Key:"
cat openwrt_publickey

# Установить правильные права
chmod 600 openwrt_privatekey
chmod 644 openwrt_publickey
```

**⚠️ ВАЖНО:** Сохраните публичный ключ - он понадобится для добавления на сервер Keenetic!

[ ] Добавить публичный ключ клиента OpenWRT в конфигурацию сервера WG на роутере Keenetic

**Через web-интерфейс роутера Keenetic:**
- Перейти в "Интернет" → "WireGuard" → выбрать интерфейс `wg0`
- Нажать "Добавить пир"
- Указать:
  - Публичный ключ: (вставить содержимое `openwrt_publickey` с OpenWRT)
  - AllowedIPs: `10.0.0.3/32`
  - PersistentKeepalive: `25`
- Сохранить

**Через SSH на роутере Keenetic:**
```bash
# Подключиться к роутеру Keenetic
ssh -p 2222 myuser@192.168.1.1

# Добавить peer в конфигурацию
cat >> /opt/etc/wireguard/wg0.conf << 'EOF'

[Peer]
# OpenWRT Client
PublicKey = ВСТАВИТЬ_OPENWRT_PUBLIC_KEY
AllowedIPs = 10.0.0.3/32
PersistentKeepalive = 25
EOF

# Перезапустить WireGuard для применения изменений
wg-quick down wg0
wg-quick up wg0
```

[ ] Создать интерфейс WireGuard в OpenWRT (через LuCI или UCI)

**Через web-интерфейс OpenWRT (LuCI):**
- Перейти в "Network" → "Interfaces"
- Нажать "Add new interface"
- Указать:
  - Name: `wg0`
  - Protocol: `WireGuard VPN`
- Нажать "Create interface"

**Через SSH (UCI):**
```bash
# На роутере OpenWRT
# Создать новый интерфейс WireGuard
uci set network.wg0=interface
uci set network.wg0.proto='wireguard'
uci set network.wg0.private_key="$(cat /etc/wireguard/openwrt_privatekey)"
uci set network.wg0.listen_port='51821'
uci add_list network.wg0.addresses='10.0.0.3/24'

# Применить изменения
uci commit network
```

[ ] Настроить конфигурацию интерфейса WG (приватный ключ клиента, публичный ключ сервера, IP-адрес клиента в WG-LAN, endpoint сервера, AllowedIPs)

**Через web-интерфейс OpenWRT (LuCI):**
- В созданном интерфейсе `wg0` указать:
  - **General Settings:**
    - Private Key: (вставить из `/etc/wireguard/openwrt_privatekey`)
    - IP Addresses: `10.0.0.3/24`
  - **Peers:**
    - Нажать "Add peer"
    - Public Key: (публичный ключ сервера Keenetic)
    - Preshared Key: (если использовали)
    - Allowed IPs: `10.0.0.0/24, 192.168.1.0/24`
    - Endpoint Host: (внешний IP роутера Keenetic)
    - Endpoint Port: `51820`
    - Persistent Keepalive: `25`
    - Route Allowed IPs: ✓ (включить)
- Сохранить и применить

**Через SSH (UCI):**
```bash
# На роутере OpenWRT
# Получить внешний IP роутера Keenetic
KEENETIC_IP="ВНЕШНИЙ_IP_KEENETIC"

# Добавить peer (сервер Keenetic)
uci add network wireguard_wg0
uci set network.@wireguard_wg0[-1].public_key='ВСТАВИТЬ_SERVER_PUBLIC_KEY'
uci set network.@wireguard_wg0[-1].preshared_key='ВСТАВИТЬ_PRESHARED_KEY_ЕСЛИ_ЕСТЬ'
uci set network.@wireguard_wg0[-1].endpoint_host="$KEENETIC_IP"
uci set network.@wireguard_wg0[-1].endpoint_port='51820'
uci set network.@wireguard_wg0[-1].persistent_keepalive='25'
uci set network.@wireguard_wg0[-1].route_allowed_ips='1'
uci add_list network.@wireguard_wg0[-1].allowed_ips='10.0.0.0/24'
uci add_list network.@wireguard_wg0[-1].allowed_ips='192.168.1.0/24'

# Применить изменения
uci commit network
/etc/init.d/network reload
```

[ ] Настроить firewall на OpenWRT для разрешения трафика через WG-интерфейс

**Через web-интерфейс OpenWRT (LuCI):**
- Перейти в "Network" → "Firewall"
- Нажать "Add" в секции "Zones"
- Создать новую зону:
  - Name: `wg`
  - Input: `accept`
  - Output: `accept`
  - Forward: `accept`
  - Covered networks: `wg0` (выбрать созданный интерфейс)
  - Allow forward to: `lan`, `wan`
  - Allow forward from: `lan`
- Сохранить и применить

**Через SSH (UCI):**
```bash
# На роутере OpenWRT
# Создать firewall зону для WireGuard
uci add firewall zone
uci set firewall.@zone[-1].name='wg'
uci set firewall.@zone[-1].input='ACCEPT'
uci set firewall.@zone[-1].output='ACCEPT'
uci set firewall.@zone[-1].forward='ACCEPT'
uci add_list firewall.@zone[-1].network='wg0'

# Разрешить forward из wg в lan и wan
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='lan'

uci add firewall forwarding
uci set firewall.@forwarding[-1].src='wg'
uci set firewall.@forwarding[-1].dest='wan'

# Разрешить forward из lan в wg
uci add firewall forwarding
uci set firewall.@forwarding[-1].src='lan'
uci set firewall.@forwarding[-1].dest='wg'

# Применить изменения
uci commit firewall
/etc/init.d/firewall reload
```

[ ] Запустить интерфейс WireGuard на OpenWRT

**Через web-интерфейс OpenWRT (LuCI):**
- Перейти в "Network" → "Interfaces"
- Найти интерфейс `wg0`
- Нажать "Connect" или "Restart"

**Через SSH:**
```bash
# На роутере OpenWRT
# Поднять интерфейс
ifup wg0

# Проверить статус
wg show

# Проверить интерфейс
ip addr show wg0
```
[ ] Проверить подключение клиента из локальной сети `OpenWRT-LAN` (например, `192.168.99.0/24`) к серверу `Keenetic-WG`
[ ] Проверить ping роутера Keenetic из OpenWRT-LAN через WG-туннель
[ ] Проверить доступ к web-интерфейсу роутера Keenetic из OpenWRT-LAN через WG
[ ] Проверить доступ по `ssh` к роутеру Keenetic из OpenWRT-LAN через WG

