#!/bin/bash

echo "Выберите действие:"
echo "1) Создать учётки OVPN (+5)"
echo "2) Создать учётки WG"

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

    echo "Удаляем текущий конфигурационный файл..."
    rm -f /etc/wireguard/wg00.conf

    echo "Создаем конфигурацию для $count учёток..."
    echo "[Interface]" > /etc/wireguard/wg00.conf
    echo "PrivateKey = <ваш_private_key>" >> /etc/wireguard/wg00.conf
    echo "Address = 10.0.0.1/24" >> /etc/wireguard/wg00.conf

    for i in $(seq 1 $count); do
      ip=$((i + 1))
      echo "" >> /etc/wireguard/wg00.conf
      echo "[Peer]" >> /etc/wireguard/wg00.conf
      echo "PublicKey = ключ_$i" >> /etc/wireguard/wg00.conf
      echo "AllowedIPs = 10.0.0.$ip/32" >> /etc/wireguard/wg00.conf
      echo "Добавлен клиент $i с IP 10.0.0.$ip"
    done

    echo "Запускаем вспомогательный скрипт /usr/local/openvpn_scripts/wg.sh..."
    bash /usr/local/openvpn_scripts/wg.sh

    echo "Поднимаем интерфейс wg00..."
    wg-quick up wg00

    echo "Готово! WireGuard работает с $count учётками."
    ;;
  *)
    echo "Неверный выбор. Пожалуйста, запустите скрипт заново и выберите 1 или 2."
    exit 1
    ;;
esac
