#!/bin/bash

# ============================================================================
# INSTALACIÓN DE AZURE CLI EN WSL/UBUNTU
# ============================================================================

echo "🔧 Instalando Azure CLI..."

# Actualizar paquetes
sudo apt-get update

# Instalar prerequisitos
sudo apt-get install ca-certificates curl apt-transport-https lsb-release gnupg

# Descargar e instalar Microsoft signing key
sudo mkdir -p /etc/apt/keyrings
curl -sLS https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

# Agregar Azure CLI repository
AZ_REPO=$(lsb_release -cs)
echo "deb [arch=`dpkg --print-architecture` signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" |
    sudo tee /etc/apt/sources.list.d/azure-cli.list

# Actualizar e instalar
sudo apt-get update
sudo apt-get install azure-cli

# Verificar instalación
az --version

echo "✅ Azure CLI instalado correctamente!"
echo "🔐 Ahora ejecuta: az login"