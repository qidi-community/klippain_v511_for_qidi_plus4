#!/bin/bash

USER_CONFIG_PATH="${HOME}/printer_data/config"
MOONRAKER_CONFIG="${HOME}/printer_data/config/moonraker.conf"
KLIPPER_PATH="${HOME}/klipper"
KLIPPER_VENV_PATH="${KLIPPER_VENV:-${HOME}/klippy-env}"

OLD_K_SHAKETUNE_VENV="${HOME}/klippain_shaketune-env"
K_SHAKETUNE_PATH="${HOME}/klippain_v511_for_qidi_plus4"

set -eu
export LC_ALL=C


function preflight_checks {
    if [ "$EUID" -eq 0 ]; then
        echo "[PRE-CHECK] This script must not be run as root!"
        exit -1
    fi

    if ! command -v python3 &> /dev/null; then
        echo "[ERROR] Python 3 is not installed. Please install Python 3 to use the Shake&Tune module!"
        exit -1
    fi

    if [ "$(sudo systemctl list-units --full -all -t service --no-legend | grep -F 'klipper.service')" ]; then
        printf "[PRE-CHECK] Klipper service found! Continuing...\n\n"
    else
        echo "[ERROR] Klipper service not found, please install Klipper first!"
        exit -1
    fi

    if [ ! -e resonance_tester.py ]; then
	echo "[ERROR] Please run the install script from within the directory where the install script is located"
	exit -1
    fi

    if [ ! -e shaper_calibrate.py ]; then
	echo "[ERROR] Please run the install script from within the directory where the install script is located"
	exit -1
    fi

    if [ ! -e install.sh ]; then
	echo "[ERROR] Please run the install script from within the directory where the install script is located"
	exit -1
    fi

    install_package_requirements
}

# Function to check if a package is installed
function is_package_installed {
    dpkg -s "$1" &> /dev/null
    return $?
}

function install_package_requirements {
    packages=("libopenblas-dev" "libatlas-base-dev")
    packages_to_install=""

    for package in "${packages[@]}"; do
        if is_package_installed "$package"; then
            echo "$package is already installed"
        else
            packages_to_install="$packages_to_install $package"
        fi
    done

    if [ -n "$packages_to_install" ]; then
        echo "Installing missing packages: $packages_to_install"
        sudo apt update && sudo apt install -y $packages_to_install
    fi
}

function setup_venv {
    if [ ! -d "${KLIPPER_VENV_PATH}" ]; then
        echo "[ERROR] Klipper's Python virtual environment not found!"
        exit -1
    fi

    if [ -d "${OLD_K_SHAKETUNE_VENV}" ]; then
        echo "[INFO] Old K-Shake&Tune virtual environment found, cleaning it!"
        rm -rf "${OLD_K_SHAKETUNE_VENV}"
    fi

    declare -x PS1=""
    source "${KLIPPER_VENV_PATH}/bin/activate"
    echo "[SETUP] Installing/Updating K-Shake&Tune dependencies..."
    pip install --upgrade pip
    pip install -r "${K_SHAKETUNE_PATH}/requirements.txt"
    deactivate
    printf "\n"
}

function link_extension {
    # Reusing the old linking extension function to cleanup and remove the macros for older S&T versions

    if [ -d "${HOME}/klippain_config" ] && [ -f "${USER_CONFIG_PATH}/.VERSION" ]; then
        if [ -d "${USER_CONFIG_PATH}/scripts/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG_PATH}/scripts/K-ShakeTune"
        fi
    else
        if [ -d "${USER_CONFIG_PATH}/K-ShakeTune" ]; then
            echo "[INFO] Old K-Shake&Tune macro folder found, cleaning it!"
            rm -d "${USER_CONFIG_PATH}/K-ShakeTune"
        fi
    fi
}

function link_module {
    echo "[INSTALL] Linking Shake&Tune module to Klipper extras"
    ln -frsn ${K_SHAKETUNE_PATH}/shaketune ${KLIPPER_PATH}/klippy/extras/shaketune
}

function update_klipper {
    DATE=$(date +"%Y%m%d%H%M%S")
    mkdir -p ${K_SHAKETUNE_PATH}/backups
    cp /home/mks/klipper/klippy/extras/resonance_tester.py ${K_SHAKETUNE_PATH}/backups/resonance_tester.py.$DATE
    cp /home/mks/klipper/klippy/extras/shaper_calibrate.py ${K_SHAKETUNE_PATH}/backups/shaper_calibrate.py.$DATE
    cp resonance_tester.py shaper_calibrate.py /home/mks/klipper/klippy/extras
}

function restart_klipper {
    echo "[POST-INSTALL] Restarting Klipper..."
    sudo systemctl restart klipper
}

function restart_moonraker {
    echo "[POST-INSTALL] Restarting Moonraker..."
    sudo systemctl restart moonraker
}

printf "\n=============================================\n"
echo "- Klippain Shake&Tune module install script -"
printf "=============================================\n\n"


# Run steps
preflight_checks
setup_venv
link_extension
link_module
update_klipper
restart_klipper
restart_moonraker
