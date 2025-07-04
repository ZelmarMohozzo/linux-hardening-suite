#!/bin/bash

# Autor: ZELMAR MOHOZZO

# Colores para más estética
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\e[36m"
MAGENTA="\e[35m"
RED="\e[31m"
BOLD="\e[1m"
RESET="\e[0m"

# Rutas a los scripts - ajusta según ubicación
SCRIPT_SETUP_USER="./01-setup-user.sh"
SCRIPT_FIREWALL="./02-firewall.sh"
SCRIPT_FAIL2BAN="./03-fail2ban.sh"
SCRIPT_SSH_HARDENING="./04-ssh-hardening.sh"
SCRIPT_SELINUX="./05-selinux.sh"

mostrar_titulo_ascii() {
cat << "E0F"
  ______         _                                _    _                      
 |___  /        | |                              | |  | |                     
    / /    ___  | |  _ __ ___     __ _   _ __    | |__| |   __ _   ____   ___ 
   / /    / _ \ | | | '_ ` _ \   / _` | | '__|   |  __  |  / _` | |_  /  / _ \
  / /__  |  __/ | | | | | | | | | (_| | | |      | |  | | | (_| |  / /  |  __/
 /_____|  \___| |_| |_| |_| |_|  \__,_| |_|      |_|  |_|  \__,_| /___|  \___|

                                                                                                                                                       
E0F
}

mostrar_menu() {
    clear
    echo -e "${CYAN}${BOLD}============================================================"
    mostrar_titulo_ascii
    echo -e "     ${BOLD}CREADO POR ZELMAR MOHOZZO${RESET}${CYAN}"
    echo -e "============================================================${RESET}"
    echo
    echo -e "${YELLOW}${BOLD} Scripts de Hardening Automático para Servidores Linux${RESET}"
    echo -e "${MAGENTA}Colección de scripts modulares para automatizar mejores prácticas de ciberseguridad en servidores Linux${RESET}"
    echo
    echo -e "${YELLOW} 1) Configurar usuario (Setup user)"
    echo -e " 2) Configurar Firewall"
    echo -e " 3) Configurar Fail2ban"
    echo -e " 4) Fortalecimiento SSH (SSH Hardening)"
    echo -e " 5) Configurar SELinux"
    echo -e " 6) Salir${RESET}"
    echo
    # Apartado Seguridad
    echo -e "${BOLD}${GREEN}=============== Seguridad ===============${RESET}"
    echo -e "${GREEN} Código auditado"
    echo -e " Sin vulnerabilidades"
    echo -e " Prácticas seguras${RESET}"
    echo
    echo -ne "${GREEN}Seleccione una opción [1-6]: ${RESET}"
}

ejecutar_script() {
    local script="$1"
    echo
    if [[ -x "$script" ]]; then
        echo -e "${CYAN}Ejecutando ${BOLD}$script${RESET}${CYAN}...${RESET}"
        echo
        "$script"
    else
        echo -e "${RED}Error:${RESET} El script '${BOLD}$script${RESET}' no existe o no tiene permisos de ejecución."
    fi
    echo -e "\n${YELLOW}Presione Enter para volver al menú...${RESET}"
    read -r
}

while true; do
    mostrar_menu
    read -r opcion
    case "$opcion" in
        1) ejecutar_script "$SCRIPT_SETUP_USER" ;;
        2) ejecutar_script "$SCRIPT_FIREWALL" ;;
        3) ejecutar_script "$SCRIPT_FAIL2BAN" ;;
        4) ejecutar_script "$SCRIPT_SSH_HARDENING" ;;
        5) ejecutar_script "$SCRIPT_SELINUX" ;;
        6)
            echo -e "\n${CYAN}Gracias por usar esta interfaz, ¡hasta luego!${RESET}"
            exit 0
            ;;
        *)
            echo -e "${RED}Opción inválida. Intente nuevamente.${RESET}"
            sleep 1
            ;;
    esac
done