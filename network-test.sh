#!/bin/bash

# Скрипт тестирования сетевой конфигурации Keenetic + WireGuard
# Версия: 1.0

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Символы для статуса
CHECK_MARK="${GREEN}✓${NC}"
CROSS_MARK="${RED}✗${NC}"
QUESTION_MARK="${YELLOW}?${NC}"

# Конфигурация (настроить под вашу сеть)
KEENETIC_IP="192.168.1.1"
SERVER_IP="192.168.1.11"
WG_SUBNET="10.0.0.0/24"
LAN_SUBNET="192.168.1.0/24"

# Функция для проверки команды
check_command() {
    command -v "$1" >/dev/null 2>&1
}

# Функция для вывода заголовка
print_header() {
    echo -e "\n${BLUE}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════${NC}\n"
}

# Функция для вывода теста
print_test() {
    local test_name="$1"
    local status="$2"
    local details="$3"

    printf "%-50s %s" "$test_name" "$status"
    if [ -n "$details" ]; then
        echo " ($details)"
    else
        echo ""
    fi
}

# Определение текущей сетевой зоны
detect_network_zone() {
    print_header "Определение сетевой зоны"

    local my_ip=$(hostname -I | awk '{print $1}')
    local zone="unknown"

    # Проверка WireGuard
    if ip addr show | grep -q "wg0"; then
        if sudo wg show 2>/dev/null | grep -q "latest handshake"; then
            zone="WG-LAN (активный туннель)"
        fi
    fi

    # Проверка локальной сети
    if [[ "$my_ip" =~ ^192\.168\.1\. ]]; then
        if [ "$zone" == "unknown" ]; then
            zone="Keenetic-LAN"
        fi
    elif [[ "$my_ip" =~ ^192\.168\.99\. ]]; then
        zone="OpenWRT-LAN"
    elif [[ "$my_ip" =~ ^10\.0\.0\. ]]; then
        if [ "$zone" == "unknown" ]; then
            zone="WG-LAN (только WG IP)"
        fi
    fi

    echo -e "IP-адрес: ${GREEN}$my_ip${NC}"
    echo -e "Сетевая зона: ${GREEN}$zone${NC}"

    CURRENT_ZONE="$zone"
}

# Проверка доступности по ping
test_ping() {
    local host="$1"
    local name="$2"

    if ping -c 2 -W 2 "$host" >/dev/null 2>&1; then
        print_test "Ping $name ($host)" "$CHECK_MARK"
        return 0
    else
        print_test "Ping $name ($host)" "$CROSS_MARK"
        return 1
    fi
}

# Проверка HTTP/HTTPS доступности
test_http() {
    local url="$1"
    local name="$2"

    if check_command curl; then
        if curl -f -s -m 5 "$url" >/dev/null 2>&1; then
            print_test "HTTP(S) $name" "$CHECK_MARK" "$url"
            return 0
        else
            print_test "HTTP(S) $name" "$CROSS_MARK" "$url"
            return 1
        fi
    else
        print_test "HTTP(S) $name" "$QUESTION_MARK" "curl не установлен"
        return 2
    fi
}

# Проверка SSH доступности
test_ssh() {
    local host="$1"
    local port="$2"
    local name="$3"

    if check_command nc; then
        if nc -z -w 3 "$host" "$port" 2>/dev/null; then
            print_test "SSH $name ($host:$port)" "$CHECK_MARK"
            return 0
        else
            print_test "SSH $name ($host:$port)" "$CROSS_MARK"
            return 1
        fi
    else
        print_test "SSH $name" "$QUESTION_MARK" "nc не установлен"
        return 2
    fi
}

# Проверка DNS разрешения
test_dns() {
    local domain="$1"
    local expected_ip="$2"

    if check_command nslookup; then
        local resolved_ip=$(nslookup "$domain" 2>/dev/null | grep -A1 "Name:" | grep "Address:" | awk '{print $2}' | head -1)

        if [ -n "$resolved_ip" ]; then
            if [ "$resolved_ip" == "$expected_ip" ]; then
                print_test "DNS: $domain" "$CHECK_MARK" "$resolved_ip"
                return 0
            else
                print_test "DNS: $domain" "$CROSS_MARK" "Получен: $resolved_ip, ожидался: $expected_ip"
                return 1
            fi
        else
            print_test "DNS: $domain" "$CROSS_MARK" "Не разрешается"
            return 1
        fi
    else
        print_test "DNS: $domain" "$QUESTION_MARK" "nslookup не установлен"
        return 2
    fi
}

# Проверка WireGuard
test_wireguard() {
    print_header "Проверка WireGuard"

    if ! check_command wg; then
        print_test "WireGuard установлен" "$CROSS_MARK"
        return 1
    fi

    print_test "WireGuard установлен" "$CHECK_MARK"

    if ip addr show wg0 >/dev/null 2>&1; then
        print_test "Интерфейс wg0 существует" "$CHECK_MARK"

        if sudo wg show wg0 2>/dev/null | grep -q "latest handshake"; then
            local handshake=$(sudo wg show wg0 latest-handshakes 2>/dev/null)
            print_test "Handshake активен" "$CHECK_MARK"

            # Проверка времени последнего handshake
            local last_handshake_time=$(sudo wg show wg0 latest-handshakes | awk '{print $2}')
            local current_time=$(date +%s)
            local time_diff=$((current_time - last_handshake_time))

            if [ $time_diff -lt 180 ]; then
                print_test "Handshake свежий" "$CHECK_MARK" "$time_diff сек назад"
            else
                print_test "Handshake устарел" "$YELLOW!$NC" "$time_diff сек назад"
            fi
        else
            print_test "Handshake активен" "$CROSS_MARK"
        fi
    else
        print_test "Интерфейс wg0 существует" "$CROSS_MARK"
    fi
}

# Проверка доступности роутера
test_router() {
    print_header "Проверка роутера Keenetic"

    test_ping "$KEENETIC_IP" "роутер"
    test_http "http://$KEENETIC_IP" "web-интерфейс (HTTP)"
    test_http "https://$KEENETIC_IP" "web-интерфейс (HTTPS)"
    test_ssh "$KEENETIC_IP" "2222" "SSH"
}

# Проверка локального сервера
test_local_server() {
    print_header "Проверка локального сервера"

    test_ping "$SERVER_IP" "сервер"
    test_http "http://$SERVER_IP:9898" "тестовый web-сервер"
    test_dns "srvok.ckox" "$SERVER_IP"
    test_http "http://srvok.ckox:9898" "доступ по доменному имени"
}

# Проверка HTTPS сервисов
test_https_services() {
    print_header "Проверка HTTPS сервисов"

    test_http "https://srvok.ckox" "главный сервис"
    test_http "https://keenetic.srvok.ckox" "роутер через прокси"
    test_http "https://nas.srvok.ckox" "NAS сервис"

    # Проверка DNS для поддоменов
    test_dns "keenetic.srvok.ckox" "$SERVER_IP"
    test_dns "nas.srvok.ckox" "$SERVER_IP"
}

# Проверка SSL сертификатов
test_ssl_certificates() {
    print_header "Проверка SSL сертификатов"

    if check_command openssl; then
        local domains=("srvok.ckox" "keenetic.srvok.ckox" "nas.srvok.ckox")

        for domain in "${domains[@]}"; do
            if echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | grep -q "Verify return code: 0"; then
                print_test "SSL сертификат: $domain" "$CHECK_MARK" "Валидный"
            else
                local verify_code=$(echo | openssl s_client -connect "$domain:443" -servername "$domain" 2>/dev/null | grep "Verify return code" | head -1)
                print_test "SSL сертификат: $domain" "$CROSS_MARK" "$verify_code"
            fi
        done
    else
        print_test "Проверка SSL" "$QUESTION_MARK" "openssl не установлен"
    fi
}

# Генерация отчета
generate_summary() {
    print_header "ИТОГОВАЯ СВОДКА"

    echo -e "${GREEN}Сетевая зона:${NC} $CURRENT_ZONE"
    echo -e "${GREEN}Время теста:${NC} $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Все проверки завершены."
    echo ""
    echo -e "${YELLOW}Примечание:${NC}"
    echo "  $CHECK_MARK - Тест пройден успешно"
    echo "  $CROSS_MARK - Тест провален"
    echo "  $QUESTION_MARK - Невозможно выполнить тест (отсутствуют инструменты)"
}

# Главная функция
main() {
    clear
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════╗"
    echo "║   Скрипт тестирования сети Keenetic + WireGuard          ║"
    echo "╚═══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Проверка запуска от root для команд WireGuard
    if [ "$EUID" -ne 0 ]; then
        echo -e "${YELLOW}Предупреждение: Для полной проверки WireGuard запустите с sudo${NC}\n"
    fi

    detect_network_zone
    test_wireguard
    test_router
    test_local_server
    test_https_services
    test_ssl_certificates
    generate_summary
}

# Запуск
main "$@"
