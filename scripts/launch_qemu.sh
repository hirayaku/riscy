#!/bin/bash

help_msg ()
{
    echo "Usage: $BASH_SOURCE <kernel> [rootfs image]"
    exit $1
}

if [[ $# == 1 ]]; then
    kernel=$1
    w_rootfs=n
elif [[ $# == 2 ]]; then
    kernel=$1
    rootfs=$2
    w_rootfs=y
else
    help_msg 2
fi

if [[ $w_rootfs == y ]]; then
    qemu-system-riscv64 -nographic -machine virt -m 1G \
        -kernel "$kernel" -append "root=/dev/vda rw console=ttyS0" \
        -drive file=$rootfs,format=raw,id=hd0 \
        -device virtio-blk-device,drive=hd0 \
        -device virtio-net-device,netdev=usernet -netdev user,id=usernet,hostfwd=tcp::22222-:22
else
    qemu-system-riscv64 -nographic -machine virt \
        -kernel "$kernel"
fi

