#!/bin/bash

while true; do
echo "═══════════════════════════════════════"
echo "       Главное меню управления VPN"
echo "═══════════════════════════════════════"
echo "1) Создать учётки OVPN (+5)"
echo "2) Создать учётки WireGuard"
echo "3) IP1>IP2 (Замена IP-адресов)"
echo "0) Выход"
echo "═══════════════════════════════════════"

read -r choice </dev/tty

case $choice in
  1)
    echo ""
    echo "→ Запуск скрипта создания учёток OVPN..."
    python /usr/local/openvpn_scripts/menu.py < /dev/tty > /dev/tty 2>&1
    
    if [ $? -eq 0 ]; then
      echo ""
      echo "✓ Учётки OVPN успешно созданы!"
      echo ""
    else
      echo ""
      echo "✗ Ошибка при создании учёток OVPN"
      echo ""
    fi
    ;;
    
  2)
    echo ""
    echo "→ Создание учёток WireGuard"
    echo "Сколько учёток добавить?"
    read count </dev/tty

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -le 0 ]; then
      echo "✗ Ошибка: введите корректное положительное число."
      echo ""
      continue
    fi

    echo ""
    echo "[1/5] Останавливаем интерфейс wg00..."
    wg-quick down wg00 2>/dev/null
    
    echo "[2/5] Удаляем старый конфигурационный файл..."
    rm -f /etc/wireguard/wg00.conf
    
    echo "[3/5] Генерируем $count учёток через wg.sh..."
    # Модифицируем wg.sh на лету с нужным количеством
    sed -i "s/for i in {1\.\.[0-9]*}/for i in {1..$count}/" /usr/local/openvpn_scripts/wg.sh
    bash /usr/local/openvpn_scripts/wg.sh
    
    echo "[4/5] Поднимаем интерфейс wg00..."
    wg-quick up wg00
    
    if [ $? -eq 0 ]; then
      echo "[5/5] Обновляем веб-конфигурации..."
      # Генерируем QR-коды для новых конфигов
      cd /var/www/html/*/ 2>/dev/null && \
      find . -iname '*.conf' -exec sh -c "cat {} | qrencode -t PNG -o {}.png" \; 2>/dev/null
      
      echo ""
      echo "✓ Готово! WireGuard работает с $count учётками."
      echo "✓ Конфигурации доступны на веб-сайте"
      echo ""
    else
      echo ""
      echo "✗ Ошибка при запуске WireGuard"
      echo ""
    fi
    ;;
    
  3)
    echo ""
    echo "→ Замена IP1 на IP2 во всех конфигурациях..."
    echo ""
    
    # Определяем IP-адреса
    iplist=$(ip a | grep "inet " | grep -v '127.0.0.1\|10.180.' | cut -d "/" -f1 | rev | cut -d " " -f1 | rev)
    ip1=$(echo $iplist | cut -d " " -f1)
    ip2=$(echo $iplist | cut -d " " -f2)
    
    echo "IP1: $ip1 → IP2: $ip2"
    echo ""
    
    # 3proxy
    echo "[1/6] Обновляем 3proxy..."
    sed -i "s/internal ${ip1}/internal ${ip2}/g" /etc/3proxy.cfg && service 3proxy restart && echo "      ✓ 3proxy обновлён"
    
    # OpenVPN
    echo "[2/6] Обновляем OpenVPN..."
    sed -i "s/local ${ip1}/local ${ip2}/g" /etc/openvpn/server/server-udp.conf && \
    sed -i "s/local ${ip1}/local ${ip2}/g" /etc/openvpn/server/server-tcp.conf && \
    systemctl restart openvpn-server@server-tcp.service && \
    systemctl restart openvpn-server@server-udp.service && \
    echo "      ✓ OpenVPN обновлён"
    
    # OpenVPN конфиги клиентов
    echo "[3/6] Обновляем конфиги клиентов OpenVPN..."
    cd /var/www/html/*/ && \
    find . -type f -name "*.ovpn" | xargs sed -i "s/${ip1}/${ip2}/g" && \
    rm -f all.zip *.png && \
    zip -q all.zip *.ovpn && \
    echo "      ✓ Конфиги клиентов обновлены"
    
    # QR-коды
    echo "[4/6] Генерируем QR-коды..."
    cd /var/www/html/*/ && \
    find . -iname '*.conf' -exec sh -c "cat {} | qrencode -t PNG -o {}.png" \; 2>/dev/null && \
    echo "      ✓ QR-коды созданы"
    
    # iptables
    echo "[5/6] Обновляем iptables..."
    sed -i "s/${ip1}/${ip2}/g" /etc/sysconfig/iptables && \
    service iptables save && \
    systemctl restart iptables.service && \
    echo "      ✓ iptables обновлён"
    
    # WireGuard
    echo "[6/6] Перезапускаем WireGuard..."
    systemctl restart wg-quick@wg00.service && \
    echo "      ✓ WireGuard перезапущен"
    
    echo ""
    echo "✓ Готово! IP-адреса успешно заменены во всех конфигурациях."
    echo ""
    ;;
    
  0)
    echo ""
    echo "→ Выход из скрипта..."
    exit 0
    ;;
    
  *)
    echo ""
    echo "✗ Неверный выбор. Выберите 1, 2, 3 или 0."
    echo ""
    ;;
esac
done
