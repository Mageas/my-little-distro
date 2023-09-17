#!/bin/bash

MLD_PACKAGES_DIR="packages"
MLD_CACHE_DIR=".cache_packages"

declare -A MLD_PACKAGES
declare -A MLD_AUR_PACKAGES
declare -A MLD_FLATPAKS
declare -A MLD_CACHE_PACKAGES
declare -A MLD_CACHE_AUR_PACKAGES
declare -A MLD_CACHE_FLATPAKS

# Clear variables
# If variables are not cleared, it can be reused
function clear_vars {
    ENABLE=false
    PACKAGES=()
    DEPENDENCIES=()
    AUR_PACKAGES=()
    AUR_DEPENDENCIES=()
    FLATPAK_PACKAGES=()
    FLATPAK_DEPENDENCIES=()
}

# Remove the parent directory
# $1 path
# $2 directory name
function remove_parent_directory {
    return_remove_parent_directory=$(echo "${1/$2\//}")
}

# Get the array difference
# Count array a and test count on array b
# $1 array a
# $1 array b
function get_array_diff {
    declare -n arr=$1
    declare -n cnt=$2
    declare -A _count
    for element in ${arr[@]}; do
        let _count["$element"]++
    done

    # Sort packages to uninstall if orphan
    return_count_array=()
    for element in ${cnt[@]}; do
        [[ ${_count[$element]} -eq 0 ]] || continue
        return_count_array+=($element)
    done
}

# Helper to set the value of an associative array
# $1 variable name of the array
# $2 key
# $3 path of the file
# $@ values to set
function set_value {
    declare -n arr=$1
    index="$2?$3"
    shift 3
    arr["$index"]="$@"
}

# Index the packages
function indexing_packages {
    while IFS= read -r -d '' file; do
        [[ ${file} != *.conf ]] && continue
        if [[ "${file}" =~ \ |\' ]]; then
            echo "Skip '${file}' spaces are not allowed"
            continue
        fi
        clear_vars
        source "${file}"

        [[ "${ENABLE}" != true ]] && continue

        remove_parent_directory "${file}" "${MLD_PACKAGES_DIR}"

        set_value "MLD_PACKAGES" "pkgs" "${return_remove_parent_directory}" "${PACKAGES[@]}"
        set_value "MLD_PACKAGES" "deps" "${return_remove_parent_directory}" "${DEPENDENCIES[@]}"
        set_value "MLD_AUR_PACKAGES" "pkgs" "${return_remove_parent_directory}" "${AUR_PACKAGES[@]}"
        set_value "MLD_AUR_PACKAGES" "deps" "${return_remove_parent_directory}" "${AUR_DEPENDENCIES[@]}"
        set_value "MLD_FLATPAKS" "pkgs" "${return_remove_parent_directory}" "${FLATPAK_PACKAGES[@]}"
        set_value "MLD_FLATPAKS" "deps" "${return_remove_parent_directory}" "${FLATPAK_DEPENDENCIES[@]}"
    done < <(find ${MLD_PACKAGES_DIR} -type f -print0)
}

# Save the indexed packages
# PACKAGES are saved in CONFIG_CACHE_PACKAGES
# AUR PACKAGES are saved in CONFIG_CACHE_AUR_PACKAGES
# FLATPAK are saved in CONFIG_CACHE_FLATPAKS
function save_indexing_cache {
    local _output="#!/bin/bash\ndeclare -A CONFIG_CACHE_PACKAGES"
    for key in "${!MLD_PACKAGES[@]}"; do
        [[ ! -z "${MLD_PACKAGES[$key]}" ]] && _output+="\nCONFIG_CACHE_PACKAGES[${key}]=\"${MLD_PACKAGES[$key]}\""
    done
    _output+="\ndeclare -A CONFIG_CACHE_AUR_PACKAGES"
    for key in "${!MLD_AUR_PACKAGES[@]}"; do
        [[ ! -z "${MLD_AUR_PACKAGES[$key]}" ]] && _output+="\nCONFIG_CACHE_AUR_PACKAGES[${key}]=\"${MLD_AUR_PACKAGES[$key]}\""
    done
    _output+="\ndeclare -A CONFIG_CACHE_FLATPAKS"
    for key in "${!MLD_FLATPAKS[@]}"; do
        [[ ! -z "${MLD_FLATPAKS[$key]}" ]] && _output+="\nCONFIG_CACHE_FLATPAKS[${key}]=\"${MLD_FLATPAKS[$key]}\""
    done
    echo -e "${_output}" >"${MLD_CACHE_DIR}"
}

# Index the cache
function indexing_cache {
    [[ ! -f "${MLD_CACHE_DIR}" ]] && return
    source "${MLD_CACHE_DIR}"
    for key in "${!CONFIG_CACHE_PACKAGES[@]}"; do
        MLD_CACHE_PACKAGES[$key]="${CONFIG_CACHE_PACKAGES[$key]}"
    done
    for key in "${!CONFIG_CACHE_AUR_PACKAGES[@]}"; do
        MLD_CACHE_AUR_PACKAGES[$key]="${CONFIG_CACHE_AUR_PACKAGES[$key]}"
    done
    for key in "${!CONFIG_CACHE_FLATPAKS[@]}"; do
        MLD_CACHE_FLATPAKS[$key]="${CONFIG_CACHE_FLATPAKS[$key]}"
    done
}

indexing_packages
indexing_cache
save_indexing_cache

# Packages to remove
get_array_diff "MLD_PACKAGES" "MLD_CACHE_PACKAGES"
echo "pkgs del diff: ${return_count_array[@]}"
# Packages to install
get_array_diff "MLD_CACHE_PACKAGES" "MLD_PACKAGES"
echo "pkgs ins diff: ${return_count_array[@]}"

# Aur packages to remove
get_array_diff "MLD_AUR_PACKAGES" "MLD_CACHE_AUR_PACKAGES"
echo "aur pkgs del diff: ${return_count_array[@]}"
# Aur packages to install
get_array_diff "MLD_CACHE_AUR_PACKAGES" "MLD_AUR_PACKAGES"
echo "aur pkgs ins diff: ${return_count_array[@]}"

# Flatpaks to remove
get_array_diff "MLD_FLATPAKS" "MLD_CACHE_FLATPAKS"
echo "flatpak del diff: ${return_count_array[@]}"
# Flatpaks to install
get_array_diff "MLD_CACHE_FLATPAKS" "MLD_FLATPAKS"
echo "flatpak ins diff: ${return_count_array[@]}"
