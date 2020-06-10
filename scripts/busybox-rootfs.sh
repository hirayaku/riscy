#!/bin/bash

# The rootfs image build script has been modified and is copyright(C) 2020 by Tianhao Huang tianhaoh@mit.edu.
# The busybear build system has been written by and is copyright (C) 2017 by Michael J. Clark michaeljclark@mac.com.
# Enhancements to the build system have been contributed by and are copyright (C) 2017 by Karsten Merker merker@debian.org.
#
# The busybear build system is provided under the following license ("MIT license"):
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -e

# check permission
if [[ $(whoami) !=  root ]]; then
    echo "${BASH_SOURCE}: Root privilege required"
    exit -1
fi

# check prerequisites
for exe in dd chown rsync openssl; do
    if [[ -z $(which $exe) ]]; then
        echo "${BASH_SOURCE}: $exe not found in PATH"
        exit -1
    fi
done

# before executing this script, vars:
# uid, gid, RISCV, XLEN, ABI, IMAGE_FILE, IMAGE_SIZE, BUSYBOX_DIR
# need to be set
for var in RISCV XLEN ABI IMAGE_FILE IMAGE_SIZE BUSYBOX_DIR ETC_DIR; do
    [[ -z ${!var} ]] && ( echo "${BASH_SOURCE}: Set var $var before executing"; exit -1 )
done

if [[ -z ${ROOT_PASSWORD} ]]; then
    ROOT_PASSWORD="passwd"
fi

#
# locate compiler
#
GCC_DIR=${RISCV}
if [[ ! -e ${GCC_DIR}/bin/riscv${XLEN}-unknown-linux-gnu-gcc ]]; then
    echo "Cannot find gcc executable under ${GCC_DIR}"
    echo "Is the riscv$XLEN toolchain properly built?"
    exit -1
fi

#
# create root filesystem
#
rm -f ${IMAGE_FILE}
dd if=/dev/zero of=${IMAGE_FILE} bs=1M count=${IMAGE_SIZE}
chown ${uid}:${gid} ${IMAGE_FILE}
/sbin/mkfs.ext4 -j -F ${IMAGE_FILE}
test -d mnt || mkdir mnt
mount -o loop ${IMAGE_FILE} mnt

set +e

#
# copy libraries, flattening symlink directory structure
#
copy_libs() {
    for lib in $1/*.so*; do
        if [[ ${lib} =~ (^libgomp.*|^libgfortran.*|.*\.py$) ]]; then
            : # continue
        elif [[ -e "$2/$(basename $lib)" ]]; then
            : # continue
        elif [[ -h "$lib" ]]; then
            ln -s $(basename $(readlink $lib)) $2/$(basename $lib)
        else
            cp -a $lib $2/$(basename $lib)
        fi
    done
}

#
# configure root filesystem
#
(
    set -e

    # create directories
    for dir in root bin dev etc lib lib/modules proc sbin sys tmp \
        usr usr/bin usr/sbin var var/run var/log var/tmp
        # etc/dropbear \
        # etc/network/if-pre-up.d \
        # etc/network/if-up.d \
        # etc/network/if-down.d \
        # etc/network/if-post-down.d
    do
        mkdir -p mnt/${dir}
    done

    # copy busybox and dropbear
    # cp build/busybox-${BUSYBOX_VERSION}/busybox mnt/bin/
    # cp build/dropbear-${DROPBEAR_VERSION}/dropbear mnt/sbin/

    cp ${BUSYBOX_DIR}/busybox mnt/bin/

    # for minimal rootfs, we use statically linked busybox so no libraries are needed
    # for a more practical linux environment, you will need to include some libraries in $RISCV/sysroot
    # copy libraries
    # if [ -d ${GCC_DIR}/sysroot/usr/lib${XLEN}/${ABI}/ ]; then
    #     ABI_DIR=lib${XLEN}/${ABI}
    # else
    #     ABI_DIR=lib
    # fi
    # LDSO_NAME=ld-linux-riscv${XLEN}-${ABI}.so.1
    # LDSO_TARGET=$(readlink ${GCC_DIR}/sysroot/lib/${LDSO_NAME})
    # mkdir -p mnt/${ABI_DIR}/
    # copy_libs $(dirname ${GCC_DIR}/sysroot/lib/${LDSO_TARGET})/ mnt/${ABI_DIR}/
    # copy_libs ${GCC_DIR}/sysroot/usr/${ABI_DIR}/ mnt/${ABI_DIR}/
    # what does the following mean?
    # if [ ! -e mnt/lib/${LDSO_NAME} ]; then
    #     ln -s /${ABI_DIR}/$(basename ${LDSO_TARGET}) mnt/lib/${LDSO_NAME}
    # fi

    # final configuration
    rsync -a ${ETC_DIR}/ mnt/etc/
    # hash=$(openssl passwd -1 -salt xyzzy ${ROOT_PASSWORD})
    # sed -i'' "s:\*:${hash}:" mnt/etc/shadow
    # chmod 600 mnt/etc/shadow
    touch mnt/var/log/lastlog
    touch mnt/var/log/wtmp
    ln -s ../bin/busybox mnt/sbin/init
    ln -s busybox mnt/bin/sh
    # cp bin/ldd mnt/bin/ldd
    mknod mnt/dev/console c 5 1
    mknod mnt/dev/ttyS0 c 4 64
    mknod mnt/dev/null c 1 3
)

#
# remove if configure failed
#
if [[ $? -ne 0 ]]; then
    echo "*** failed to create ${IMAGE_FILE}"
    rm -f ${IMAGE_FILE}
else
    echo "+++ successfully created ${IMAGE_FILE}"
    ls -l ${IMAGE_FILE}
fi

#
# finish
#
umount mnt
rmdir mnt

