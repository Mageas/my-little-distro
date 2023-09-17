#!/bin/bash

MLD_PACKAGES_DIR="packages"
MLD_CACHE_DIR=".cache_packages"

declare -A MLD_PACKAGES
declare -A MLD_AUR_PACKAGES
declare -A MLD_FLATPAK
declare -A MLD_CACHE_PACKAGES
declare -A MLD_CACHE_AUR_PACKAGES
declare -A MLD_CACHE_FLATPAK
PACKAGES_PATH=()
CACHES_PATH=()

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
        PACKAGES_PATH+=(${return_remove_parent_directory})

        set_value "MLD_PACKAGES" "pkgs" "${return_remove_parent_directory}" "${PACKAGES[@]}"
        set_value "MLD_PACKAGES" "deps" "${return_remove_parent_directory}" "${DEPENDENCIES[@]}"
        set_value "MLD_AUR_PACKAGES" "pkgs" "${return_remove_parent_directory}" "${AUR_PACKAGES[@]}"
        set_value "MLD_AUR_PACKAGES" "deps" "${return_remove_parent_directory}" "${AUR_DEPENDENCIES[@]}"
        set_value "MLD_FLATPAK" "pkgs" "${return_remove_parent_directory}" "${FLATPAK_PACKAGES[@]}"
        set_value "MLD_FLATPAK" "deps" "${return_remove_parent_directory}" "${FLATPAK_DEPENDENCIES[@]}"
    done < <(find ${MLD_PACKAGES_DIR} -type f -print0)
}

# Save the indexed packages
# PACKAGES are saved in CACHE_CONFIG
# AUR PACKAGES are saved in CACHE_AUR_CONFIG
# FLATPAK are saved in CACHE_FLATPAK_CONFIG
function save_indexing_cache {
    local _output="#!/bin/bash\ndeclare -A CACHE_CONFIG"
    for key in "${!MLD_PACKAGES[@]}"; do
        [[ ! -z "${MLD_PACKAGES[$key]}" ]] && _output+="\nCACHE_CONFIG[${key}]=\"${MLD_PACKAGES[$key]}\""
    done
    _output+="\ndeclare -A CACHE_AUR_CONFIG"
    for key in "${!MLD_AUR_PACKAGES[@]}"; do
        [[ ! -z "${MLD_AUR_PACKAGES[$key]}" ]] && _output+="\nCACHE_AUR_CONFIG[${key}]=\"${MLD_AUR_PACKAGES[$key]}\""
    done
    _output+="\ndeclare -A CACHE_FLATPAK_CONFIG"
    for key in "${!MLD_FLATPAK[@]}"; do
        [[ ! -z "${MLD_FLATPAK[$key]}" ]] && _output+="\nCACHE_FLATPAK_CONFIG[${key}]=\"${MLD_FLATPAK[$key]}\""
    done
    echo -e "${_output}" >"${MLD_CACHE_DIR}"
}

# Index the cache
function indexing_cache {
    source "${MLD_CACHE_DIR}"
    for key in "${!CACHE_CONFIG[@]}"; do
        MLD_CACHE_PACKAGES[$key]="${CACHE_CONFIG[$key]}"
    done
    for key in "${!CACHE_AUR_CONFIG[@]}"; do
        MLD_CACHE_AUR_PACKAGES[$key]="${CACHE_AUR_CONFIG[$key]}"
    done
    for key in "${!CACHE_FLATPAK_CONFIG[@]}"; do
        MLD_CACHE_FLATPAK[$key]="${CACHE_FLATPAK_CONFIG[$key]}"
    done
}

indexing_packages
indexing_cache
save_indexing_cache

get_array_diff "MLD_PACKAGES" "MLD_CACHE_PACKAGES"
echo "pkgs del diff: ${return_count_array[@]}"
get_array_diff "MLD_CACHE_PACKAGES" "MLD_PACKAGES"
echo "pkgs ins diff: ${return_count_array[@]}"

get_array_diff "MLD_AUR_PACKAGES" "MLD_CACHE_AUR_PACKAGES"
echo "aur pkgs del diff: ${return_count_array[@]}"
get_array_diff "MLD_CACHE_AUR_PACKAGES" "MLD_AUR_PACKAGES"
echo "aur pkgs ins diff: ${return_count_array[@]}"

get_array_diff "MLD_FLATPAK" "MLD_CACHE_FLATPAK"
echo "flatpak del diff: ${return_count_array[@]}"
get_array_diff "MLD_CACHE_FLATPAK" "MLD_FLATPAK"
echo "flatpak ins diff: ${return_count_array[@]}"
