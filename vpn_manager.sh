#!/bin/bash

echo "Выберите действие:"
echo "1) Создать учётки OVPN (+5)"
echo "2) Создать учётки WG"
echo "3) IP1>IP2"

read -r choice </dev/tty

case $choice in
  1)
    echo "Запуск скрипта создания учёток OVPN..."
    python /usr/local/openvpn_scripts/menu.py
    ;;
  2)
    echo "Создание учёток WireGuard"
    echo "Сколько учёток добавить?"
    read count </dev/tty

    if ! [[ "$count" =~ ^[0-9]+$ ]] || [ "$count" -le 0 ]; then
      echo "Ошибка: введите корректное положительное число."
      exit 1
    fi

    echo "Останавливаем интерфейс wg00..."
    wg-quick down wg00

    echo "Удаляем конфигурационный файл..."
    rm -f /etc/wireguard/wg00.conf

    echo "Генерируем $count учёток через wg.sh..."
    bash /usr/local/openvpn_scripts/wg.sh $count

    echo "Поднимаем интерфейс wg00..."
    wg-quick up wg00

    echo "Готово! WireGuard работает с $count учётками."
    ;;
  3)
    echo "Замена IP1 на IP2 во всех конфигурациях..."
    
    # Определяем IP-адреса
    iplist=$(ip a | grep "inet " | grep -v '127.0.0.1\|10.180.' | cut -d "/" -f1 | rev | cut -d " " -f1 | rev)
    ip1=$(echo $iplist | cut -d " " -f1)
    ip2=$(echo $iplist | cut -d " " -f2)
    
    echo "Заменяем IP с $ip1 на $ip2"
    
    # 3proxy
    echo "Обновляем 3proxy..."
    sed -i "s/internal ${ip1}/internal ${ip2}/g" /etc/3proxy.cfg && service 3proxy restart && echo "3proxy Ok"
    
    # OpenVPN
    echo "Обновляем OpenVPN..."
    sed -i "s/local ${ip1}/local ${ip2}/g" /etc/openvpn/server/server-udp.conf && \
    sed -i "s/local ${ip1}/local ${ip2}/g" /etc/openvpn/server/server-tcp.conf && \
    systemctl restart openvpn-server@server-tcp.service && \
    systemctl restart openvpn-server@server-udp.service && \
    echo "OpenVPN Ok"
    
    # OpenVPN конфиги клиентов
    echo "Обновляем конфиги клиентов OpenVPN..."
    cd /var/www/html/*/ && \
    find . -type f | xargs sed -i "s/${ip1}/${ip2}/g" && \
    rm -f all.zip *.png && \
    zip all.zip *.ovpn && \
    echo "OpenVPN config replace Ok"
    
    # QR-коды
    echo "Генерируем QR-коды..."
    cd /var/www/html/*/ && \
    find . -iname '*.conf' -exec sh -c "cat {} | qrencode -t PNG -o {}.png" \;
    
    # iptables
    echo "Обновляем iptables..."
    sed -i "s/${ip2}/${ip1}/g" /etc/sysconfig/iptables && \
    service iptables save && \
    systemctl restart iptables.service
    
    # WireGuard
    echo "Перезапускаем WireGuard..."
    systemctl restart wg-quick@wg00.service
    
    echo "Готово! IP-адреса заменены во всех конфигурациях."
    ;;
  *)
    echo "Неверный выбор. Пожалуйста, запустите скрипт заново и выберите 1, 2 или 3."
    exit 1
    ;;
esac
