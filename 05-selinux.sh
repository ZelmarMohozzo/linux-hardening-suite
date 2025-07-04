#!/bin/bash
# Script de Hardening - Configuración SELinux
# Autor: Zelmar Mohozzo - Code Society
# Propósito: Habilitar y configurar SELinux en modo enforcing

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

# Verificar si es una distribución compatible con SELinux
if [[ ! -f /etc/redhat-release ]] && [[ ! -f /etc/fedora-release ]]; then
    log "Detectando sistema no-Red Hat, verificando soporte SELinux..."
    if [[ -f /etc/debian_version ]]; then
        log "Sistema Debian/Ubuntu detectado, instalando SELinux..."
        apt update
        apt install -y selinux-basics selinux-policy-default auditd
        selinux-activate
        log "SELinux instalado. Se requiere reinicio para activar."
        log "Después del reinicio, ejecute este script nuevamente."
        exit 0
    else
        error "Sistema no compatible con SELinux"
        exit 1
    fi
fi

# Instalar herramientas SELinux si no están presentes
log "Instalando herramientas SELinux..."
if command -v yum &> /dev/null; then
    yum install -y policycoreutils-python-utils setroubleshoot-server setools-console
elif command -v dnf &> /dev/null; then
    dnf install -y policycoreutils-python-utils setroubleshoot-server setools-console
fi

# Verificar estado actual de SELinux
log "Verificando estado actual de SELinux..."
if command -v getenforce &> /dev/null; then
    CURRENT_STATE=$(getenforce)
    log "Estado actual de SELinux: $CURRENT_STATE"
else
    error "SELinux no está instalado o no es compatible"
    exit 1
fi

# Configurar SELinux en modo enforcing
log "Configurando SELinux en modo enforcing..."

# Verificar archivo de configuración
if [[ ! -f /etc/selinux/config ]]; then
    error "Archivo de configuración SELinux no encontrado"
    exit 1
fi

# Backup de configuración actual
cp /etc/selinux/config /etc/selinux/config.backup-$(date +%Y%m%d-%H%M%S)

# Configurar SELinux
cat > /etc/selinux/config << 'EOF'
# Configuración SELinux - Code Society Hardening
# Autor: Zelmar Mohozzo

# Este archivo controla el estado de SELinux en el sistema
# SELINUX puede ser: enforcing, permissive, disabled
SELINUX=enforcing

# SELINUXTYPE puede ser: targeted, minimum, mls
SELINUXTYPE=targeted
EOF

# Establecer contextos SELinux para directorios comunes
log "Configurando contextos SELinux..."

# Restaurar contextos por defecto
restorecon -R /etc
restorecon -R /var
restorecon -R /home

# Configurar contextos para SSH si se cambió el puerto
if [[ -f /etc/ssh/sshd_config ]]; then
    SSH_PORT=$(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}')
    if [[ -n "$SSH_PORT" && "$SSH_PORT" != "22" ]]; then
        log "Configurando contexto SELinux para puerto SSH personalizado: $SSH_PORT"
        semanage port -a -t ssh_port_t -p tcp $SSH_PORT 2>/dev/null ||         semanage port -m -t ssh_port_t -p tcp $SSH_PORT
    fi
fi

# Configurar políticas SELinux para servicios comunes
log "Configurando políticas SELinux..."

# Permitir que httpd se conecte a la red (si está instalado)
if systemctl is-enabled httpd &> /dev/null || systemctl is-enabled apache2 &> /dev/null; then
    setsebool -P httpd_can_network_connect on
    log "Habilitada conectividad de red para httpd"
fi

# Permitir que nginx se conecte a la red (si está instalado)
if systemctl is-enabled nginx &> /dev/null; then
    setsebool -P httpd_can_network_connect on
    log "Habilitada conectividad de red para nginx"
fi

# Crear política personalizada para aplicaciones específicas
log "Creando política personalizada..."
cat > /tmp/custom_hardening.te << 'EOF'
module custom_hardening 1.0;

require {
    type admin_home_t;
    type user_home_t;
    type ssh_port_t;
    class tcp_socket { bind listen };
    class file { read write };
}

# Política personalizada para hardening
# Permitir conexiones SSH en puertos personalizados
allow sshd_t ssh_port_t:tcp_socket { bind listen };
EOF

# Compilar y cargar política personalizada
if [[ -f /tmp/custom_hardening.te ]]; then
    checkmodule -M -m -o /tmp/custom_hardening.mod /tmp/custom_hardening.te
    semodule_package -o /tmp/custom_hardening.pp -m /tmp/custom_hardening.mod
    semodule -i /tmp/custom_hardening.pp
    rm -f /tmp/custom_hardening.*
    log "Política personalizada aplicada"
fi

# Configurar auditd para monitoreo SELinux
log "Configurando auditd para monitoreo SELinux..."
systemctl enable auditd
systemctl start auditd

# Configurar logrotate para logs SELinux
cat > /etc/logrotate.d/selinux << 'EOF'
/var/log/audit/audit.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
    create 0640 root root
    postrotate
        /sbin/service auditd restart > /dev/null 2>&1 || true
    endscript
}
EOF

# Verificar configuración
log "Verificando configuración SELinux..."

# Mostrar estado actual
sestatus

# Mostrar contextos importantes
log "Contextos SELinux importantes:"
ls -Z /etc/ssh/sshd_config
ls -Z /etc/selinux/config

# Mostrar políticas booleanas importantes
log "Políticas booleanas importantes:"
getsebool -a | grep -E "(httpd_can_network_connect|ssh_sysadm_login|allow_user_exec_content)"

# Verificar si se requiere reinicio
if [[ "$CURRENT_STATE" != "Enforcing" ]]; then
    warning "Se requiere reinicio para activar SELinux en modo enforcing"
    log "Después del reinicio, SELinux estará en modo enforcing"
    
    # Crear archivo de relabel automático
    touch /.autorelabel
    log "Configurado relabel automático de archivos en próximo reinicio"
fi

log "✓ SELinux configurado en modo enforcing"
log "✓ Política targeted aplicada"
log "✓ Contextos de seguridad configurados"
log "✓ Auditd habilitado para monitoreo"
log "✓ Políticas personalizadas aplicadas"

# Mostrar comandos útiles
echo
echo "Comandos útiles de SELinux:"
echo "  sestatus                              # Ver estado SELinux"
echo "  getenforce                            # Ver modo actual"
echo "  setenforce [Enforcing|Permissive]     # Cambiar modo temporal"
echo "  restorecon -R /path                   # Restaurar contextos"
echo "  semanage port -l | grep ssh           # Ver puertos SSH"
echo "  sealert -a /var/log/audit/audit.log   # Analizar alertas"
echo "  ausearch -m avc                       # Buscar eventos SELinux"

if [[ "$CURRENT_STATE" != "Enforcing" ]]; then
    warning "IMPORTANTE: Reinicie el sistema para activar SELinux en modo enforcing"
fi

exit 0