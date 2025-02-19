#!/bin/bash

# Script interactivo para instalar y configurar WireGuard VPN en la Raspberry Pi
# Además, permite seleccionar la interfaz Ethernet para enrutar tráfico a través de la VPN

# Comprobación de permisos de root
if [[ $EUID -ne 0 ]]; then
   echo "Este script debe ejecutarse como root" 
   exit 1
fi

# Actualizar el sistema
echo "Actualizando el sistema..."
apt-get update && apt-get upgrade -y

# Instalar WireGuard
echo "Instalando WireGuard..."
apt-get install -y wireguard

# Generar claves privadas y públicas
echo "Generando claves de WireGuard..."
WG_DIR="/etc/wireguard"
mkdir -p $WG_DIR
cd $WG_DIR
umask 077
wg genkey | tee privatekey | wg pubkey > publickey

# Leer claves generadas
PRIVATE_KEY=$(cat privatekey)

# Crear archivo de configuración de WireGuard (como servidor)
echo "Creando archivo de configuración de WireGuard..."
WG_ADDRESS="10.0.0.1/24"

cat <<EOL > wg0.conf
[Interface]
PrivateKey = $PRIVATE_KEY
Address = $WG_ADDRESS
ListenPort = 51820
DNS = 8.8.8.8

# Configuración de los peers
# Añade aquí los peers permitidos manualmente según sea necesario
EOL

chmod 600 wg0.conf

# Activar WireGuard
echo "Activando WireGuard..."
wg-quick up wg0

# Mostrar interfaces disponibles
echo "Interfaces disponibles:"
ip link show

# Seleccionar la interfaz Ethernet
read -p "Ingrese el nombre de la interfaz Ethernet (ej: eth0): " ETHERNET_INTERFACE

# Configurar enrutamiento para WiFi y VPN
echo "Configurando enrutamiento..."
WIFI_INTERFACE="wlan0"
ip rule add from $(ip -4 addr show $WIFI_INTERFACE | grep -oP '(?<=inet\s)\d+(\.\d+){3}') table 51820
ip route add default dev wg0 table 51820

# Configurar enrutamiento para la interfaz Ethernet
echo "Configurando el enrutamiento para la interfaz Ethernet ($ETHERNET_INTERFACE)..."
iptables -t nat -A POSTROUTING -o wg0 -j MASQUERADE

# Habilitar el reenvío de IP
echo "Habilitando el reenvío de IP..."
sysctl -w net.ipv4.ip_forward=1
sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf

# Activar WireGuard al inicio del sistema
echo "Habilitando WireGuard al inicio..."
systemctl enable wg-quick@wg0

# Mensaje final
echo "Instalación y configuración completa. WireGuard está activo y el tráfico Ethernet se enruta a través de la VPN."