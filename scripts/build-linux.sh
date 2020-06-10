#!/bin/bash

# Copyright (c) 2020 Massachusetts Institute of Technology

# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without
# restriction, including without limitation the rights to use, copy,
# modify, merge, publish, distribute, sublicense, and/or sell copies
# of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:

# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
# BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
# ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

set -e

help_msg ()
{
    echo "Usage: $0 [--prefix=PREFIX] [-u PART| --update=PART] [-f| --force]"
    echo "          [--kernel=KVERSION] [--busybox=BVERSION] [--rootfs=IMG] [--size=SIZE]"
    echo "          [--xlen=XLEN]"
    echo "          [-j [N]|--jobs=N] [-h|--help]"
    echo "Build firmware and kernel of KVERSION for riscv platforms whose xlen"
    echo "(32 or 64 bit) is specified by XLEN; the defaut is riscv64 (--xlen=64)"
    echo
    echo "--prefix=PREFIX           place the generated files in PREFIX [$RISCV]"
    echo "--update=PART | -u PART   rebuilt PART, PART = busybox|linux|bbl|rootfs|all"
    echo "                          if PART=busybox, rootfs will also be rebuilt;"
    echo "                          if PART=linux, bbl will also be rebuilt [all]"
    echo "-f | --force              force rebuilding of PART"
    echo
    echo "--kernel=KVERSION         specify the version of linux kernel to build [5.7-rc7]"
    echo "--busybox=BVERSION        specify the version of busybox to build [1.21.1]"
    echo "--rootfs=IMG              specify the name of generated rootfs image [rootfs.img]"
    echo "--size=SIZE               specify the size of generated rootfs image in MB [32]"
    echo
    echo "--xlen=XLEN               specify the xlen of targeted platform, 32 or 64 [64]"
    echo "--j[N]|--jobs=N           build targets using N threads concurrently [$((($(nproc) + 1)/2))]"
    echo "-h|--help                 print this message"
    exit $1
}

info ()
{
    echo -n "$(tput setaf 2)[INFO] $(tput sgr0)"
    for arg in "$*"; do
        echo -n $arg
    done
    echo
}

warn ()
{
    echo -n "$(tput setaf 1)[WARN] $(tput sgr0)"
    for arg in "$*"; do
        echo -n $arg
    done
    echo
}

if [[ -z $RISCV ]]; then
    warn "Source the generated script to setup the environment for riscv (RISCV, e.g.) first"
    exit -1
fi

if [[ -z $BASH_SOURCE ]]; then
    warn "BASH_SOURCE is empty! Check how you invoke scripts"
    exit -1
fi

XLEN=64
PREFIX=$RISCV
PART=
FORCE=
KVERSION="5.7-rc7"
BVERSION="1.21.1"
IMG=rootfs.img
SIZE=32
JOBS=$((($(nproc) + 1)/2))  # use half hardware threads for building by default

while [[ -n "$1" ]]; do
    case "$1" in
    -h | --help )
        help_msg 0
        ;;
    --xlen )
        shift
        # read XLEN
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "XLEN not specified"
            help_msg 2
        fi
        XLEN=$1
        ;;
    --prefix )
        shift
        # read PREFIX
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "PREFIX not specified"
            help_msg 2
        fi
        PREFIX=$(realpath $1)
        ;;
    --prefix=* )
        PREFIX=$(realpath ${1#--prefix=})
        ;;
    -u )
        shift
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "-u PART not specified"
            help_msg 2
        fi
        PART="$PART $1"
        ;;
    --update=*)
        PART="$PART ${1#--update=}"
        ;;
    -f | --force )
        FORCE=y
        ;;
    --kernel )
        shift
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "kernel version not specified"
            help_msg 2
        fi
        KVERSION=$1
        ;;
    --kernel=* )
        KVERSION=${1#--kernel=}
        ;;
    --busybox )
        shift
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "busybox version not specified"
            help_msg 2
        fi
        BVERSION=$1
        ;;
    --busybox=* )
        BVERSION=${1#--busybox=}
        ;;
    --rootfs=* )
        IMG=${1#--rootfs=}
        ;;
    --size=* )
        SIZE=${1#--size=}
        ;;
    -j )
        shift
        if [[ -z $1 ]] || [[ $1 =~ ^- ]]; then
            warn "N (Number of concurrent jobs) not specified"
            help_msg 2
        fi
        JOBS=$1
        ;;
    --jobs=* )
        JOBS=${1#--jobs=}
        ;;
    * )
        warn "Unrecognized argument: $1"
        help_msg 2
    esac
    shift
done

#
# check opts
#
if [[ $XLEN == 32 ]]; then
    CROSS_COMPILE_LINUX=riscv32-unknown-linux-gnu-
    CROSS_COMPILE_ELF=riscv32-unknown-elf-
elif [[ $XLEN == 64 ]]; then
    CROSS_COMPILE_LINUX=riscv64-unknown-linux-gnu-
    CROSS_COMPILE_ELF=riscv64-unknown-elf-
else
    warn "Unrecognized argument for XLEN: $XLEN"
    help_msg 1
fi

if [[ ! $KVERSION =~ ^[0-9]*\.[0-9]*(-rc[1-9][0-9]*)*$ ]]; then
    warn "Invalid format for kernel version: $KVERSION"
    help_msg 1
fi

if [[ ! $BVERSION =~ ^[0-9]*\.[0-9]*.[0-9]*$ ]]; then
    warn "Invalid format for busybox version: $BVERSION"
    help_msg 1
fi

if [[ ! $SIZE =~ ^[1-9][0-9]*$ ]]; then
    warn "Invalid format for rootfs image size: $SIZE (MB)"
    help_msg 1
fi

if [[ ! $JOBS =~ ^[1-9][0-9]*$ ]]; then
    warn "Invalid format for N (number of concurrent jobs): $JOBS"
    help_msg 1
fi

MAKE="make -j $JOBS"
MAKEINSTALL="make install"

[[ -z $PART ]] && PART=all
upd_busybox=
upd_linux=
upd_bbl=
upd_rootfs=

for part in $PART; do
    case $part in
    busybox )
        upd_busybox=y
        upd_rootfs=y
        ;;
    linux )
        upd_linux=y
        upd_bbl=y
        ;;
    bbl )
        upd_bbl=y
        ;;
    rootfs )
        upd_rootfs=y
        ;;
    all )
        upd_busybox=y
        upd_linux=y
        upd_bbl=y
        upd_rootfs=y
        ;;
    * )
        warn "Unrecoginized argument for -u, --update: $part"
        help_msg 2
    esac
done

#
# download <user/repo> in the current directory
# e.g. download "riscv/riscv-gnu-toolchain"
#
git-download ()
{
    local repo=$1
    local name=${1##*/} # get suffix
    local commit=$2
    local cwd=$PWD

    if [[ -z $name ]]; then
        warn "Invalid repo format: $repo"
        exit -1
    fi

    # get complete remote url
    [[ $repo =~ ^(https://|http://) ]] || repo="https://github.com/$repo"

    # download if not exist
    if [[ ! -d $name ]]; then
        git clone $repo
    fi
    # checkout
    cd $name
    if [[ -n $commit ]]; then
        git checkout $commit
    else
        git checkout master
    fi
    git submodule update --init --depth=1
    git submodule update --recursive

    cd $cwd
}

# configuration directory
script_dir="$(dirname $(realpath ${BASH_SOURCE}))"
conf_dir="$(dirname $(realpath ${BASH_SOURCE}))/conf"

cwd=$PWD


bb_archive=busybox-$BVERSION.tar.bz2
bb_dir=$(realpath busybox-$BVERSION)
busybox=$bb_dir/busybox
if [[ -n $upd_busybox ]]; then
    # download busybox
    info "Checkout busybox $BVERSION"
    if [[ ! -d $bb_dir ]]; then
        [[ -f archive/$bb_archive ]] || (mkdir -p archive && wget https://www.busybox.net/downloads/$bb_archive -O archive/$bb_archive)
        mkdir -p $bb_dir && tar -xf archive/$bb_archive -C $bb_dir --strip-components 1
        info "Busybox $BVERSION source extracted to $bb_dir"
    else
        info "Busybox $BVERSION source already downloaded"
    fi
    echo

    # build busybox
    info "Building busybox $BVERSION..."
    [[ -n $FORCE ]] && rm -f $busybox
    if [[ ! -f $busybox ]]; then
        cd $bb_dir
        [[ -n $FORCE ]] && $MAKE clean
        cp $conf_dir/busybox.config $bb_dir/.config
        $MAKE ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE_LINUX menuconfig
        $MAKE ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE_LINUX
        info "busybox built: $busybox"
        cd $cwd
    else
        info "busybox already built: $busybox"
    fi
    echo
fi


if [[ -n $upd_rootfs ]]; then
    # create rootfs image
    info "Creating rootfs image..."
    sudo uid=$(id -u) gid=$(id -g) RISCV=$RISCV XLEN=$XLEN ABI=lp${XLEN}d IMAGE_FILE=$IMG IMAGE_SIZE=$SIZE BUSYBOX_DIR=$bb_dir ETC_DIR=$script_dir/etc \
        bash $script_dir/busybox-rootfs.sh

    info "rootfs image generated: $IMAGE_FILE"
    echo
fi


ker_archive=linux-$KVERSION.tar.gz
linux_dir=$(realpath linux-$KVERSION)
vmlinux=$linux_dir/vmlinux
if [[ -n $upd_linux ]]; then
    # download linux kernel
    info "Checkout linux kernel $KVERSION"
    if [[ ! -d $linux_dir ]]; then
        [[ -f archive/$ker_archive ]] || (mkdir -p archive && wget https://github.com/torvalds/linux/archive/v$KVERSION.tar.gz -O archive/$ker_archive)
        mkdir -p $linux_dir && tar -xf archive/$ker_archive -C $linux_dir --strip-components 1
        info "Kernel $KVERSION source extracted to $linux_dir"
    else
        info "Kernel $KVERSION source already downloaded"
    fi
    echo ""

    # build linux kernel
    info "Building linux kernel $KVERSION..."
    [[ -n $FORCE ]] && rm -f $vmlinux
    if [[ ! -f $vmlinux ]]; then
        cd $linux_dir
        [[ -n $FORCE ]] && $MAKE clean
        cp $conf_dir/linux-busybear.config $linux_dir/.config
        $MAKE ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE_LINUX olddefconfig
        # check config
        if ! (grep -qE ^CONFIG_ARCH_RV${XLEN}I $linux_dir/.config); then # && grep -qE ^CONFIG_SIFIVE_PLIC $linux_dir/.config); then
            warn "Check the generated kernel configuration: both CONFIG_ARCH_RV$XLEN and CONFIG_SIFIVE_PLIC should be set"
            exit -1
        fi
        $MAKE ARCH=riscv CROSS_COMPILE=$CROSS_COMPILE_LINUX vmlinux
        info "vmlinux built: $vmlinux"
        cd $cwd
    else
        info "vmlinux already built: $vmlinux"
    fi
    echo ""
fi


pk_dir=$(realpath riscv-pk)
bbl=$PREFIX/${CROSS_COMPILE_LINUX%-}/bin/bbl
if [[ -n $upd_bbl ]]; then
    # download riscv-pk
    info "Checkout riscv-pk"
    git-download riscv/riscv-pk
    info "riscv-pk cloned to $pk_dir"
    echo

    # build bbl with vmlinux as the payload
    info "Building bbl..."
    [[ -n $FORCE ]] && rm -f $bbl
    if [[ ! -f $bbl ]]; then
        cd $pk_dir
        mkdir -p build && cd build
        ../configure --enable-logo --prefix=$PREFIX --host=${CROSS_COMPILE_LINUX%-} --with-payload=$vmlinux
        [[ -n $FORCE ]] && $MAKE clean
        $MAKE
        $MAKEINSTALL
        info "bbl generated: $bbl"
        cd $cwd
    else
        info "bbl already generated: $bbl"
    fi
    echo ""
fi

