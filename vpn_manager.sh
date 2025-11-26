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

    echo "Удаляем конфигурационный файл..."
    rm -f /etc/wireguard/wg00.conf

    echo "Генерируем $count учёток через wg.sh..."
    bash /usr/local/openvpn_scripts/wg.sh $count

    echo "Поднимаем интерфейс wg00..."
    wg-quick up wg00

    echo "Готово! WireGuard работает с $count учётками."
    ;;
  *)
    echo "Неверный выбор. Пожалуйста, запустите скрипт заново и выберите 1 или 2."
    exit 1
    ;;
esac
