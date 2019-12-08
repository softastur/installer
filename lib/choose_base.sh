#!/usr/bin/env bash

menu_title="${install_op_msg}"

# Kernel and base selection menu
while (true); do
    install_menu=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${install_type_message}" 17 69 8 \
        1 "${base_msg0}" \
        2 "${base_msg1}" \
        3 "${hardened_msg0}" \
        4 "${hardened_msg1}" \
        5 "${LTS_msg0}" \
        6 "${LTS_msg1}" \
        7 "${zen_msg0}" \
        8 "${zen_msg1}" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${exit_msg}" 10 60); then
            main_menu
        fi
    else
        break
    fi
done

case "${install_menu}" in
    1) base_install=('base' 'linux' 'linux-headers') ;;
    2) base_install=('base-devel' 'linux' 'linux-headers') ;;
    3) base_install=('base' 'linux-hardened' 'linux-hardened-headers') ;;
    4) base_install=('base-devel' 'linux-hardened' 'linux-hardened-headers') ;;
    5) base_install=('base' 'linux-lts' 'linux-lts-headers') ;;
    6) base_install=('base-devel' 'linux-lts' 'linux-lts-headers') ;;
    7) base_install=('base' 'linux-zen' 'linux-zen-headers') ;;
    8) base_install=('base-devel' 'linux-zen' 'linux-zen-headers') ;;
esac

# Shell selection menu
while (true); do
    shell=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${shell_msg}" 16 64 6 \
        "bash"  "${shell5}" \
        "dash"	"${shell0}" \
        "fish"	"${shell1}" \
        "mksh"	"${shell2}" \
        "tcsh"	"${shell3}" \
        "zsh"	"${shell4}" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${exit_msg}" 10 60); then
            main_menu
        fi
    else
        case "${shell}" in
            bash)   sh="/bin/bash" base_install+=('bash-completion') ;;
            fish)   sh="/usr/bin/fish" ;;
            zsh)    sh="/usr/bin/zsh" base_install+=('zsh' 'zsh-syntax-highlighting')
                    shrc=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "\n${shrc_msg}" 13 65 4 \
                        "${default}"        "${shrc_msg1}" \
                        "oh-my-zsh"		    "${shrc_msg2}" \
                        "grml-zsh-config"	"${shrc_msg4}" \
                        "${none}"			"${shrc_msg3}" 3>&1 1>&2 2>&3)

                if [[ $? -ne 0 ]]; then
                    shrc="${default}"
                fi

                if [[ "${shrc}" == "oh-my-zsh" ]]; then
                    aur_packages+=('oh-my-zsh-git')
                elif [[ "${shrc}" == "grml-zsh-config" ]]; then
                    aur_packages+=('grml-zsh-config' 'zsh-completions')
                fi
            ;;
            *) sh="/bin/${shell}" ;;
        esac

        base_install+=("${shell}")
        break
    fi
done

# Boot loader selection menu
while (true); do
    if "${UEFI}" ; then
        bootloader=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${loader_type_msg}" 13 64 4 \
            "grub"			"${loader_msg}" \
            "syslinux"		"${loader_msg1}" \
            "systemd-boot"	"${loader_msg2}" \
            "efistub"	    "${loader_msg3}" \
            "${none}" "-" 3>&1 1>&2 2>&3)
        exit_code=$?
    else
        bootloader=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${loader_type_msg}" 12 64 3 \
            "grub"			"${loader_msg}" \
            "syslinux"		"${loader_msg1}" \
            "${none}" "-" 3>&1 1>&2 2>&3)
        exit_code=$?
    fi

    if [[ ${exit_code} -ne 0 ]]; then
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${exit_msg}" 10 60); then
            main_menu
        fi
    elif [[ "${bootloader}" == "systemd-boot" ]]; then
        break
    elif [[ "${bootloader}" == "efistub" ]]; then
        break
    elif [[ "${bootloader}" == "syslinux" ]]; then
        if ! "${UEFI}" ; then
            if (tune2fs -l /dev/"${BOOT}" | grep "64bit" &> /dev/null); then
                if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n${syslinux_warn_msg}" 11 60); then
                    mnt=$(df | grep -w "${BOOT}" | awk '{print $6}')
                    (umount "${mnt}"
                    wipefs -a /dev/"${BOOT}"
                    mkfs.ext4 -O \^64bit /dev/"${BOOT}"
                    mount /dev/"${BOOT}" "${mnt}") &> /dev/null &
                    pid=$! pri=0.1 msg="\n${boot_load} \n\n \Z1> \Z2mkfs.ext4 -O ^64bit /dev/${BOOT}\Zn" load
                    base_install+=("${bootloader}")
                    break
                fi
            else
                base_install+=("${bootloader}")
                break
            fi
        else
            base_install+=("${bootloader}")
            break
        fi
    elif [[ "${bootloader}" == "grub" ]]; then
        base_install+=("${bootloader}")
        break
    else
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${grub_warn_msg0}" 10 60); then
            dialog --ok-button "${ok}" --msgbox "\n${grub_warn_msg1}" 10 60
            break
        fi
    fi
done

while (true); do
    net_util=$(dialog --ok-button "${ok}" --cancel-button "${cancel}" --menu "${wifi_util_msg}" 13 64 3 \
        "networkmanager" 	"${net_util_msg1}" \
        "netctl"			"${net_util_msg0}" \
        "${none}"           "-" 3>&1 1>&2 2>&3)

    if [[ $? -ne 0 ]]; then
        if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${exit_msg}" 10 60); then
            main_menu
        fi
    else
        if [[ "${net_util}" == "netctl" ]] || [[ "${net_util}" == "networkmanager" ]]; then
            base_install+=("${net_util}" 'dialog')
            enable_nm=true
        fi
        break
    fi
done

if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n\n${multilib_msg}" 11 60); then
    multilib=true
    echo "$(date -u "+%F %H:%M") : Include multilib" >> "${log}"
fi

if (dialog --yes-button "${yes}" --no-button "${no}" --yesno "\n\n${dhcp_msg}" 11 60); then
    dhcp=true
    echo "$(date -u "+%F %H:%M") : Enable dhcp" >> "${log}"
fi

if "${wifi}" ; then
    base_install+=('wireless_tools' 'wpa_supplicant')
else
    if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${wifi_option_msg}" 10 60); then
        base_install+=('wireless_tools' 'wpa_supplicant')
    fi
fi

if "${bluetooth}" ; then
    if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${bluetooth_msg}" 10 60); then
        base_install+=('bluez' 'bluez-utils' 'pulseaudio-bluetooth')
        enable_bt=true
    fi
fi

if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${pppoe_msg}" 10 60); then
    base_install+=('rp-pppoe')
fi

if (dialog --defaultno --yes-button "${yes}" --no-button "${no}" --yesno "\n${os_prober_msg}" 10 60); then
    base_install+=('os-prober')
fi

if "${enable_f2fs}" ; then
    base_install+=('f2fs-tools')
fi

if "${UEFI}" ; then
    base_install+=('efibootmgr')
fi

# Append the selected packages to the packages file
for package in "${base_install[@]}"; do
    echo -e "${package}" >> packages_file
done

for aur_package in "${aur_packages[@]}"; do
    echo -e "${aur_package}" >> aur_packages_file
done

# vim: ai:ts=4:sw=4:et