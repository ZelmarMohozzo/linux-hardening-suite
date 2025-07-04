#!/bin/bash
# Script de Hardening - Configuración de Usuario Seguro
# Autor: Zelmar Mohozzo - Code Society
# Propósito: Establecer usuario con sudo y deshabilitar root remoto

set -euo pipefail

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Función de logging
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Solicitar información del nuevo usuario
read -p "Ingrese el nombre del nuevo usuario: " NEW_USER
read -s -p "Ingrese la contraseña para $NEW_USER: " NEW_PASSWORD
echo

# Crear usuario con directorio home
log "Creando usuario $NEW_USER..."
useradd -m -s /bin/bash "$NEW_USER"

# Establecer contraseña
echo "$NEW_USER:$NEW_PASSWORD" | chpasswd

# Agregar usuario al grupo sudo
log "Agregando $NEW_USER al grupo sudo..."
usermod -aG sudo "$NEW_USER"

# Configurar sudoers para no requerir contraseña (opcional)
read -p "¿Permitir sudo sin contraseña para $NEW_USER? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "$NEW_USER ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/"$NEW_USER"
    chmod 0440 /etc/sudoers.d/"$NEW_USER"
    log "Configurado sudo sin contraseña para $NEW_USER"
fi

# Deshabilitar login root directo
log "Deshabilitando login root directo..."
passwd -l root

# Configurar SSH para deshabilitar root login
if [[ -f /etc/ssh/sshd_config ]]; then
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
    log "Deshabilitado PermitRootLogin en SSH"
fi

log "✓ Configuración de usuario seguro completada"
log "✓ Usuario $NEW_USER creado con permisos sudo"
log "✓ Acceso root remoto deshabilitado"

exit 0