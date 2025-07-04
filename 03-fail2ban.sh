#!/bin/bash
# Script de Hardening - Instalación y Configuración de Fail2ban
# Autor: Zelmar Mohozzo - Code Society
# Propósito: Proteger contra ataques de fuerza bruta

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

# Detectar distribución
if [[ -f /etc/debian_version ]]; then
    DISTRO="debian"
elif [[ -f /etc/redhat-release ]]; then
    DISTRO="redhat"
elif [[ -f /etc/arch-release ]]; then
    DISTRO="arch"
else
    error "Distribución no soportada"
    exit 1
fi

# Instalar Fail2ban
log "Instalando Fail2ban..."
case $DISTRO in
    "debian")
        apt update
        apt install -y fail2ban
        ;;
    "redhat")
        yum install -y epel-release
        yum install -y fail2ban
        ;;
    "arch")
        pacman -Sy fail2ban
        ;;
esac

# Crear configuración personalizada
log "Configurando Fail2ban..."
cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Tiempo de ban en segundos (1 hora)
bantime = 3600

# Ventana de tiempo para contar intentos fallidos (10 minutos)
findtime = 600

# Número máximo de intentos fallidos antes del ban
maxretry = 3

# Ignorar IPs locales
ignoreip = 127.0.0.1/8 ::1 192.168.0.0/16 10.0.0.0/8 172.16.0.0/12

# Configuración de email (opcional)
# destemail = admin@ejemplo.com
# sender = fail2ban@ejemplo.com

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1800

[apache-auth]
enabled = false
port = http,https
filter = apache-auth
logpath = /var/log/apache2/error.log
maxretry = 3

[nginx-http-auth]
enabled = false
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[postfix-sasl]
enabled = false
port = smtp,ssmtp,submission
filter = postfix-sasl
logpath = /var/log/mail.log
maxretry = 3
EOF

# Configurar filtro personalizado para SSH
cat > /etc/fail2ban/filter.d/sshd-aggressive.conf << 'EOF'
[Definition]
failregex = ^%(__prefix_line)s(?:error: PAM: )?[aA]uthentication (?:failure|error) for .* from <HOST>( via \S+)?\s*$
            ^%(__prefix_line)s(?:error: )?Received disconnect from <HOST>: 3: \S+ \[preauth\]\s*$
            ^%(__prefix_line)s(?:error: )?Connection closed by <HOST> \[preauth\]\s*$
            ^%(__prefix_line)s(?:error: )?PAM: User not known to the underlying authentication module for .* from <HOST>\s*$
            ^%(__prefix_line)s(?:error: )?User .* from <HOST> not allowed because user is not in any group\s*$

ignoreregex = 
EOF

# Habilitar y iniciar Fail2ban
log "Habilitando Fail2ban..."
systemctl enable fail2ban
systemctl start fail2ban

# Verificar estado
log "Verificando estado de Fail2ban..."
systemctl status fail2ban --no-pager
fail2ban-client status

log "✓ Fail2ban instalado y configurado"
log "✓ Protección SSH habilitada"
log "✓ Configuración: 3 intentos fallidos = ban de 30 minutos"
log "✓ Servicio habilitado para inicio automático"

# Mostrar comandos útiles
echo
echo "Comandos útiles de Fail2ban:"
echo "  fail2ban-client status                    # Ver estado general"
echo "  fail2ban-client status sshd              # Ver estado jail SSH"
echo "  fail2ban-client set sshd unbanip <IP>    # Desbanear IP"
echo "  fail2ban-client set sshd banip <IP>      # Banear IP manualmente"

exit 