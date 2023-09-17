#!/bin/bash

#
# IMPORTANT STUFF, DO NOT TOUCH
#
MLD_PACKAGES=()
MLD_PACKAGES_INSTALL=()
MLD_AUR_PACKAGES=()
MLD_AUR_PACKAGES_INSTALL=()
declare -A MLD_PACKAGES_TO_CACHE
MLD_CACHE_UNINSTALL_PACKAGE=()
MLD_CACHE_UNINSTALL_AUR_PACKAGE=()
MLD_CACHE_UNINSTALL_PATH=()

declare -A MLD_MD5

MLD_PACKAGES_DIR="packages"
MLD_CACHE_DIR=".cache_packages"

# Update working directory to this script path
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
cd "${SCRIPT_DIR}"

function clear_vars {
    ENABLE=false
    PACKAGES=()
    DEPENDENCIES=()
    AUR_PACKAGES=()
    AUR_DEPENDENCIES=()
}

function indexing_packages {
    while IFS= read -r -d '' file; do
        [[ $file != *.conf ]] && continue
        if [[ "$file" =~ \ |\' ]]; then
            echo "Skip '${file}' spaces are not allowed"
            continue
        fi
        clear_vars
        source "${file}"

        # Generate cache path
        cache_dir_path=$(dirname "${file}")
        cache_dir_path=$(echo "${cache_dir_path/$MLD_PACKAGES_DIR/$MLD_CACHE_DIR}")
        cache_file_path=$(echo "${file/$MLD_PACKAGES_DIR/$MLD_CACHE_DIR}")

        # Generate files md5
        packages_md5=($(md5sum "${file}"))
        cache_md5=($(md5sum "${cache_file_path}" 2>/dev/null))

        # Store the md5
        MLD_MD5[${cache_file_path}]="${cache_md5} ${packages_md5}"

        MLD_PACKAGES+=("${PACKAGES[@]}" "${DEPENDENCIES[@]}")
        MLD_AUR_PACKAGES+=("${AUR_PACKAGES[@]}" "${AUR_DEPENDENCIES[@]}")

        # If the file is not updated, continue
        [[ "${packages_md5}" == "${cache_md5}" ]] && continue

        MLD_PACKAGES_INSTALL+=("${PACKAGES[@]}" "${DEPENDENCIES[@]}")
        MLD_AUR_PACKAGES_INSTALL+=("${AUR_PACKAGES[@]}" "${AUR_DEPENDENCIES[@]}")
        MLD_PACKAGES_TO_CACHE[${file}]="${cache_dir_path} ${cache_file_path}"
    done < <(find ${MLD_PACKAGES_DIR} -type f -print0)

}

function indexing_cache {
    while IFS= read -r -d '' file; do
        [[ $file != *.conf ]] && continue
        packages_file_path=$(echo "${file/$MLD_CACHE_DIR/$MLD_PACKAGES_DIR}")
        clear_vars
        source "${file}"

        local _md5=(${MLD_MD5[$file]})
        [[ "${_md5[0]}" == "${_md5[1]}" ]] && continue

        # [[ -f "${packages_file_path}" ]] && continue
        MLD_CACHE_UNINSTALL_PACKAGE+=("${PACKAGES[@]}" "${DEPENDENCIES[@]}")
        MLD_CACHE_UNINSTALL_AUR_PACKAGE+=("${AUR_PACKAGES[@]}" "${AUR_DEPENDENCIES[@]}")

        MLD_CACHE_UNINSTALL_PATH+=("${file}")
    done < <(find ${MLD_CACHE_DIR} -type f -print0)
}

function install_cache_packages {
    for package in "${!MLD_PACKAGES_TO_CACHE[@]}"; do
        local _cache=(${MLD_PACKAGES_TO_CACHE[$package]})
        mkdir -p "${_cache[0]}"
        cp "${package}" "${_cache[@]:1}"
    done
}

function install_packages {
    [[ ! -z "${MLD_PACKAGES_INSTALL[*]}" ]] && echo "Pacman -S --needed ${MLD_PACKAGES_INSTALL[@]}"
    [[ ! -z "${MLD_AUR_PACKAGES_INSTALL[*]}" ]] && echo "Paru -S --needed ${MLD_AUR_PACKAGES_INSTALL[@]}"
}

function uninstall_cache_packages {
    [ -z "${MLD_CACHE_UNINSTALL_PATH[*]}" ] && return

    rm ${MLD_CACHE_UNINSTALL_PATH[@]}
    # Remove empy directories
    find ${MLD_CACHE_DIR} -type d -exec rmdir {} + 2>/dev/null
}

function uninstall_packages {
    [[ -z "(${MLD_CACHE_UNINSTALL_PACKAGE[*]} ${MLD_CACHE_UNINSTALL_AUR_PACKAGE[*]})" ]] && return

    # Count packages
    declare -A _count_packages_to_uninstall
    for package in "${MLD_PACKAGES[@]}"; do
        let _count_packages_to_uninstall["$package"]++
    done

    # Sort packages to uninstall if orphan
    local _packages_to_uninstall=()
    for package in "${MLD_CACHE_UNINSTALL_PACKAGE[@]}"; do
        [[ ${_count_packages_to_uninstall[$package]} -ne 0 ]] && continue
        _packages_to_uninstall+=($package)
    done

    # Count aur packages
    declare -A _count_aur_packages_to_uninstall
    for package in "${MLD_AUR_PACKAGES[@]}"; do
        let _count_aur_packages_to_uninstall["$package"]++
    done

    # Sort aur packages to uninstall if orphan
    local _aur_packages_to_uninstall=()
    for package in "${MLD_CACHE_UNINSTALL_AUR_PACKAGE[@]}"; do
        [[ ${_count_aur_packages_to_uninstall[$package]} -ne 0 ]] && continue
        _aur_packages_to_uninstall+=($package)
    done

    [ ! -z "${_packages_to_uninstall[*]}" ] && echo "Pacman -Rns ${_packages_to_uninstall[@]}"
    [ ! -z "${_aur_packages_to_uninstall[*]}" ] && echo "Paru -Rns ${_aur_packages_to_uninstall[@]}"
}

indexing_packages
indexing_cache

install_cache_packages
install_packages

uninstall_cache_packages
uninstall_packages

# Problemes:
# le remove se base sur l'install pour l'index
# si un programme est supprime, l'install ne l'index pas donc le remove ne le voit pas

# Update:
#
#
