#!/bin/bash

# Script para revertir la instalación y configuración de WireGuard VPN en la Raspberry Pi
# Revierte los cambios realizados por el script de instalación

# Comprobación de permisos de root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root"
   exit 1
fi

# Desactivar WireGuard
if [ -f "/etc/wireguard/wg0.conf" ]; then
    echo "Desactivando WireGuard..."
    wg-quick down wg0
fi

# Eliminar archivo de configuración de WireGuard
echo "Eliminando archivo de configuración de WireGuard..."
rm -f /etc/wireguard/wg0.conf

# Desinstalar WireGuard
echo "Desinstalando WireGuard..."
apt-get remove -y wireguard

# Revertir enrutamiento de WiFi y VPN
echo "Revirtiendo enrutamiento..."
WIFI_INTERFACE="wlan0"
ip rule del from $(ip -4 addr show $WIFI_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}') table 51820
ip route del default dev wg0 table 51820

# Revertir enrutamiento de la interfaz Ethernet
read -p "Ingrese el nombre de la interfaz Ethernet que configuró (ej: eth0): " ETHERNET_INTERFACE
echo "Revirtiendo el enrutamiento para la interfaz Ethernet ($ETHERNET_INTERFACE)..."
iptables -t nat -D POSTROUTING -o wg0 -j MASQUERADE

# Deshabilitar el reenvío de IP
echo "Deshabilitando el reenvío de IP..."
sysctl -w net.ipv4.ip_forward=0
sed -i '/net.ipv4.ip_forward/s/^/#/' /etc/sysctl.conf

# Desactivar WireGuard al inicio del sistema
echo "Desactivando WireGuard al inicio..."
systemctl disable wg-quick@wg0

# Mensaje final
echo "Rollback completo. WireGuard ha sido desinstalado y todos los cambios han sido revertidos."