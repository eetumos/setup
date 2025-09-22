GPU=$(loginctl seat-status 2>/dev/null | rg -o "/sys/.*/drm/card[0-9]+$" -r '$0/device')

if [ $(echo -n "$GPU" | rg -c ^ || echo 0) -eq 1 ]
then
    export MESA_VK_DEVICE_SELECT=$(cat $GPU/vendor $GPU/device | sed "s/^0x//" | paste -sd:)!

    GPU=${GPU%/drm*}; GPU=${GPU##*/}
    export MANGOHUD_CONFIG=read_cfg,pci_dev=${GPU//:/\\:}
else
    unset MESA_VK_DEVICE_SELECT MANGOHUD_CONFIG
fi
