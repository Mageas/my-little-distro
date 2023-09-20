#!/bin/bash
set -e

MLD_DISKS_TO_MOUNT=(
    "UUID=20f1c47d-7f9b-4c18-8a22-e1a5fe509ef2    ${HOME}/Documents   ext4    defaults    0 0"
    "UUID=7d366d8b-7b1a-42bc-a4e2-0cd96644d2b9    ${HOME}/2TO         ext4    defaults    0 0"
)

MLD_INSTALL_PATH="${HOME}/.my-little-distro"
MLD_LOGS_FILE="${MLD_INSTALL_PATH}/logs"

MLD_DOTFILES="https://github.com/Mageas/dotfiles"
MLD_DOTFILES_PATH="${HOME}/.dots"
MLD_SYSFILES="https://github.com/Mageas/sysfiles"
MLD_SYSFILES_DIRECTORY="/opt/sysfiles"

MLD_POST_INSTALL_SCRIPT_PATH="post_install.sh"
MLD_MANAGE_PACKAGES_SCRIPT_PATH="manage_packages.sh"

#
# !! DO NOT UPDATE THE SCRIPT BELOW THIS LINE !!
#
[[ "${MLD_DOTFILES}" = "" ]] && ERROR "The variable 'MLD_DOTFILES' is not set" false
[[ "${MLD_DOTFILES_PATH}" = "" ]] && ERROR "The variable 'MLD_DOTFILES_PATH' is not set" false
[[ "${MLD_INSTALL_PATH}" = "" ]] && MLD_INSTALL_PATH="${HOME}/.my-little-distro"
[[ "${MLD_LOGS_FILE}" = "" ]] && MLD_LOGS_FILE="${MLD_INSTALL_PATH}/logs"

MLD_SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
cd "${MLD_SCRIPT_DIR}"

# Helpers
function TO_FILE {
    echo "${1}" >>"${MLD_LOGS_FILE}"
}

function LOG {
    echo -e "\033[35m\033[1m[LOG] ${1}\033[0m\n"
    set +e
    [[ "${2}" == "" || "${2}" == true ]] && TO_FILE "[LOG] ${1}"
}

function ERROR {
    echo -e "\033[0;31m\033[1m[ERROR] ${1}\033[0m\n"
    [[ "${2}" == "" || "${2}" == true ]] && TO_FILE "[ERROR] ${1}"
    exit 1
}
# --Helpers

function check_privileges {
    if [[ "$(id -u)" -eq 0 ]]; then
        echo "####################################"
        echo "This script MUST NOT be run as root!"
        echo "####################################"
        exit 1
    fi

    sudo echo ""
    [[ ${?} -eq 0 ]] || ERROR "[check_privileges]: Your root password is wrong" false
}

function init_script {
    [[ -d "${MLD_INSTALL_PATH}" ]] && ERROR "[init_script]: The install directory already exists"
    mkdir -p "${MLD_INSTALL_PATH}" || ERROR "[init_script]: Unable to create the install direcroty"

    # Init pacman
    sudo pacman -Sy --noconfirm archlinux-keyring ||
        ERROR "[init_script]: Unable to update archlinux keyring"
    sudo pacman -Syu --noconfirm ||
        ERROR "[init_script]: Unable to update archlinux"
    # Install packages dependencies
    sudo pacman -S --needed --noconfirm git rustup flatpak stow ||
        ERROR "[init_script]: Unable to install required dependencies"

    # Init arch user repository
    rustup install stable || ERROR "[init_script]: Unable to configure rustup"
    rustup default stable || ERROR "[init_script]: Unable to configure rustup"
    # Install paru
    git clone https://aur.archlinux.org/paru.git "${MLD_INSTALL_PATH}/paru" &&
        cd "${MLD_INSTALL_PATH}/paru" && makepkg -si --noconfirm --needed ||
        ERROR "[init_script]: Unable to install paru"

    # Init flatpak
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Required if git is configured to use GPG in the dotfiles
    git config --global user.email "example@mail.com"
    git config --global user.name "example"

    # Update pacman to use parallel downloads
    sudo sed -i '/^#\ParallelDownloads =/{N;s/#//g}' /etc/pacman.conf ||
        LOG "[init_script]: Unable to activate parallel downloads for pacman"
}

function install_packages {
    (
        set +e
        source "${MLD_MANAGE_PACKAGES_SCRIPT_PATH}"
        set -e

        # Install pacman packages
        if [[ "${MLD_OUTPUT_PACKAGES_INSTALL[@]}" != "" ]]; then
            sudo pacman -S --needed --noconfirm ${MLD_OUTPUT_PACKAGES_INSTALL[@]} ||
                ERROR "[install_packages]: Unable to install '${MLD_OUTPUT_PACKAGES_INSTALL[@]}' form pacman"
        fi
        # Install aur packages
        for _package in ${MLD_OUTPUT_AUR_PACKAGES_INSTALL[@]}; do
            paru -S --noconfirm --noprovides --skipreview "${_package}" ||
                LOG "[install_packages]: Unable to install '${_package}' from aur"
        done
        # Install flatpaks
        for _package in ${MLD_OUTPUT_FLATPAKS_INSTALL[@]}; do
            flatpak install -y "${_package}" ||
                LOG "[install_packages]: Unable to install '${_package}' from flatpak"
        done
    )
}

function install_dotfiles {
    git clone "${MLD_DOTFILES}" "${MLD_DOTFILES_PATH}" &&
        cd "${MLD_DOTFILES_PATH}" &&
        stow -R */ ||
        ERROR "[install_dotfiles]: Unable to install dotfiles"

    if [[ "${MLD_SYSFILES}" != "" && "${MLD_SYSFILES_DIRECTORY}" != "" ]]; then
        sudo git clone "${MLD_SYSFILES}" "${MLD_SYSFILES_DIRECTORY}" &&
            cd "${MLD_SYSFILES_DIRECTORY}" ||
            ERROR "[install_dotfiles]: Unable to install sysfiles"

        for _directory in $(ls -p | grep /); do
            while IFS= read -r _line; do
                local _file=$(echo ${_line} | grep -oP 'existing target is neither a link nor a directory: \K.*')
                [[ -z "${_file}" ]] && continue
                local _dir=$(dirname "${_file}")
                mkdir -p "${MLD_INSTALL_PATH}/backup/${_dir}"
                cp "/${_file}" "${MLD_INSTALL_PATH}/backup/${_file}"
                LOG "[install_dotfiles]: Backup file '${MLD_INSTALL_PATH}/backup/${_file}' and remove the original at '/${_file}'"
                sudo rm "/${_file}"
            done <<<"$(stow --no --verbose ${_directory} 2>&1)"
        done
        sudo stow -R */ ||
            ERROR "[install_dotfiles]: Unable to install sysfiles"
    else
        LOG "[install_dotfiles]: Skipping sysfiles installation because 'MLD_SYSFILES' and 'MLD_SYSFILES_DIRECTORY' variables are not set"
    fi
    cd "${MLD_SCRIPT_DIR}"
}

function config_fstab() {
    for _disk in "${MLD_DISKS_TO_MOUNT[@]}"; do
        local _uuid=$(echo ${_disk} | awk '{print $1}')
        [[ -n $(grep ${_uuid} "/etc/fstab") ]] && LOG "[config_fstab]: Skipping ${_uuid}" || echo "${_disk}" | sudo tee -a /etc/fstab
    done
}

function post_install() {
    source "${MLD_POST_INSTALL_SCRIPT_PATH}"
}

check_privileges
init_script
install_packages
install_dotfiles
config_fstab
post_install
