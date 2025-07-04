#!/bin/bash
# Script de Hardening - Configuración SSH Segura
# Autor: Zelmar Mohozzo - Code Society
# Propósito: Configurar SSH con mejores prácticas de seguridad

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

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

# Verificar si se ejecuta como root
if [[ $EUID -ne 0 ]]; then
   error "Este script debe ejecutarse como root"
   exit 1
fi

# Backup de configuración SSH
log "Creando backup de configuración SSH..."
cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup-$(date +%Y%m%d-%H%M%S)

# Configurar puerto SSH personalizado
read -p "Ingrese el nuevo puerto SSH (default: 2222): " SSH_PORT
SSH_PORT=${SSH_PORT:-2222}

# Configurar usuario permitido
read -p "Ingrese el usuario permitido para SSH: " SSH_USER

# Crear nueva configuración SSH
log "Aplicando configuración SSH segura..."
cat > /etc/ssh/sshd_config << EOF
# Configuración SSH Hardening - Code Society
# Autor: Zelmar Mohozzo

# Puerto personalizado
Port $SSH_PORT

# Protocolo SSH versión 2 únicamente
Protocol 2

# Direcciones de escucha
ListenAddress 0.0.0.0

# Configuración de host keys
HostKey /etc/ssh/ssh_host_rsa_key
HostKey /etc/ssh/ssh_host_ecdsa_key
HostKey /etc/ssh/ssh_host_ed25519_key

# Configuración de cifrado
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512

# Configuración de autenticación
LoginGraceTime 30
PermitRootLogin no
MaxAuthTries 3
MaxSessions 2
MaxStartups 10:30:100

# Autenticación por clave pública
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys

# Deshabilitar autenticación por contraseña
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no

# Configuración de usuarios
AllowUsers $SSH_USER
DenyUsers root

# Configuración de reenvío
AllowAgentForwarding no
AllowTcpForwarding no
GatewayPorts no
X11Forwarding no
PermitTunnel no

# Configuración de sesión
ClientAliveInterval 300
ClientAliveCountMax 2
TCPKeepAlive yes
Compression no

# Configuración de logging
SyslogFacility AUTHPRIV
LogLevel INFO

# Banner de seguridad
Banner /etc/ssh/banner

# Configuración adicional
StrictModes yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitUserEnvironment no
UsePAM yes
EOF

# Crear banner de seguridad
log "Configurando banner de seguridad..."
cat > /etc/ssh/banner << 'EOF'
***************************************************************************
                    SISTEMA PROTEGIDO - ACCESO AUTORIZADO
***************************************************************************

Este sistema está protegido por medidas de seguridad avanzadas.
Todas las conexiones son monitoreadas y registradas.

El acceso no autorizado está prohibido y será procesado según la ley.

Si no está autorizado para acceder a este sistema, desconéctese inmediatamente.

***************************************************************************
EOF

# Generar nuevas claves SSH si es necesario
log "Verificando claves SSH del servidor..."
if [[ ! -f /etc/ssh/ssh_host_ed25519_key ]]; then
    ssh-keygen -t ed25519 -f /etc/ssh/ssh_host_ed25519_key -N ""
fi

# Configurar permisos
chmod 600 /etc/ssh/ssh_host_*_key
chmod 644 /etc/ssh/ssh_host_*_key.pub
chmod 644 /etc/ssh/sshd_config
chmod 644 /etc/ssh/banner

# Configurar directorio SSH para usuario
if [[ -n "$SSH_USER" ]]; then
    USER_HOME=$(eval echo ~$SSH_USER)
    if [[ -d "$USER_HOME" ]]; then
        log "Configurando directorio SSH para $SSH_USER..."
        sudo -u $SSH_USER mkdir -p "$USER_HOME/.ssh"
        sudo -u $SSH_USER chmod 700 "$USER_HOME/.ssh"
        sudo -u $SSH_USER touch "$USER_HOME/.ssh/authorized_keys"
        sudo -u $SSH_USER chmod 600 "$USER_HOME/.ssh/authorized_keys"
        
        warning "Recuerde agregar su clave pública SSH a $USER_HOME/.ssh/authorized_keys"
    fi
fi

# Validar configuración
log "Validando configuración SSH..."
if sshd -t; then
    log "✓ Configuración SSH válida"
else
    error "Configuración SSH inválida, revirtiendo cambios..."
    cp /etc/ssh/sshd_config.backup-* /etc/ssh/sshd_config
    exit 1
fi

# Reiniciar servicio SSH
log "Reiniciando servicio SSH..."
systemctl restart sshd

# Actualizar firewall para nuevo puerto
if command -v ufw &> /dev/null; then
    ufw allow $SSH_PORT/tcp comment 'SSH Custom Port'
    ufw delete allow 22/tcp 2>/dev/null || true
fi

log "✓ SSH hardening completado"
log "✓ Puerto SSH cambiado a: $SSH_PORT"
log "✓ Autenticación por contraseña deshabilitada"
log "✓ Solo usuario $SSH_USER permitido"
log "✓ Root login deshabilitado"
log "✓ Cifrado mejorado aplicado"

warning "IMPORTANTE: Pruebe la conexión SSH en una nueva terminal antes de cerrar esta sesión"
warning "Comando de conexión: ssh -p $SSH_PORT $SSH_USER@$(hostname -I | awk '{print $1}')"

exit 0