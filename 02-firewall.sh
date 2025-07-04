#!/bin/bash
# Script de Hardening - Configuración de Firewall
# Autor: Zelmar Mohozzo - Code Society
# Propósito: Configurar UFW/iptables para seguridad básica

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Detectar si UFW está disponible
if command -v ufw &> /dev/null; then
    log "Configurando UFW (Uncomplicated Firewall)..."
    
    # Resetear reglas existentes
    ufw --force reset
    
    # Política por defecto: denegar todo entrante, permitir saliente
    ufw default deny incoming
    ufw default allow outgoing
    
    # Permitir SSH (puerto personalizable)
    read -p "Ingrese el puerto SSH (default: 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    ufw allow $SSH_PORT/tcp comment 'SSH'
    
    # Permitir HTTP y HTTPS si es servidor web
    read -p "¿Es este un servidor web? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ufw allow 80/tcp comment 'HTTP'
        ufw allow 443/tcp comment 'HTTPS'
        log "Puertos HTTP/HTTPS habilitados"
    fi
    
    # Habilitar UFW
    ufw --force enable
    
    # Mostrar status
    ufw status verbose
    
    log "✓ UFW configurado exitosamente"
    
elif command -v iptables &> /dev/null; then
    log "Configurando iptables..."
    
    # Backup de reglas existentes
    iptables-save > /etc/iptables.backup
    
    # Limpiar reglas existentes
    iptables -F
    iptables -X
    iptables -Z
    
    # Políticas por defecto
    iptables -P INPUT DROP
    iptables -P FORWARD DROP
    iptables -P OUTPUT ACCEPT
    
    # Permitir loopback
    iptables -A INPUT -i lo -j ACCEPT
    iptables -A OUTPUT -o lo -j ACCEPT
    
    # Permitir conexiones establecidas
    iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    
    # Permitir SSH
    read -p "Ingrese el puerto SSH (default: 22): " SSH_PORT
    SSH_PORT=${SSH_PORT:-22}
    iptables -A INPUT -p tcp --dport $SSH_PORT -j ACCEPT
    
    # Permitir HTTP/HTTPS si es servidor web
    read -p "¿Es este un servidor web? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        log "Puertos HTTP/HTTPS habilitados"
    fi
    
    # Guardar reglas
    iptables-save > /etc/iptables/rules.v4
    
    log "✓ iptables configurado exitosamente"
else
    error "No se encontró UFW ni iptables"
    exit 1
fi

log "✓ Firewall configurado con políticas restrictivas"
log "✓ Tráfico entrante bloqueado por defecto"
log "✓ Puertos esenciales habilitados"

exit 0
