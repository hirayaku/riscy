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

# Abort on error
set -e

DEFAULT_ISA=rv64g

# RISCV_GNU_TOOLCHAIN_COMMIT=b4dae89f85bf882852c6186b1284df11065bfcd9
# RISCV_ISA_SIM_COMMIT=d6fcfdebf6a893bf37670fd67203d18653df4a0e
# RISCV_FESVR_COMMIT=5fc1f58fba0c740ceffa353588acf44c62ccdfbc
# RISCV_TESTS_COMMIT=b747a10a7dd789620ebcde2197581ef8bf0fda33

help_msg ()
{
    echo "Usage: $0 [--arch=ARCH] [--prefix=PREFIX] [-u MOD|--update=MOD] [-j [N]|--jobs=N] [-h|--help]"
    echo "Build common tools (gnu toolchain, simulators, etc.) for riscv isa"
    echo "specified by ARCH; the defaut is riscv64imafd (--arch=rv64g)"
    echo
    echo "--arch=ARCH           specify the targeted ISA, e.g. rv32g, rv64i, rv64gc [rv64g]"
    echo "--prefix=PREFIX       install the generated files in PREFIX [$PWD/$ARCH]"
    echo "--update=MOD| -u MOD  rebuid MOD, MOD=all|toolchain|sim|fesvr|tests"
    echo "                      if MOD=toolchain, tests will also be rebuilt [all]"
    echo "--jobs=N| -j N        build targets using N threads concurrently"
    echo "--help| -h            print this message"
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

print_mod ()
{
    for mod in $1; do
        case $mod in
            toolchain)
                echo -n "riscv-gnu-toolchain "
                ;;
            fesvr)
                echo -n "riscv-fesvr "
                ;;
            sim)
                echo -n "riscv-isa-sim "
                ;;
            tests)
                echo -n "riscv-tests "
                ;;
            all)
                print_mod toolchain
                print_mod sim
                # print_mod fesvr
                print_mod tests
                ;;
            *)
                ;;
        esac
    done
}

ARCH=$DEFAULT_ISA
MOD=
JOBS=$((($(nproc) + 1)/2))  # use half hardware threads for building by default

# get opts from command line
while [[ -n "$1" ]]; do
    case "$1" in
    -h | --help )
        help_msg 0
        ;;
    --arch )
        shift
        # read ARCH
        if [[ -z "$1" ]] || [[ "$1" =~ ^- ]]; then
            warn "ARCH not specified"
            help_msg 2
        fi
        ARCH=$1
        ;;
    --arch=* )
        ARCH=${1#--arch=}
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
            warn "MOD not specified"
            help_msg 2
        fi
        MOD="$MOD $1"
        ;;
    --update=*)
        MOD="$MOD ${1#--update=}"
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

##############
# check opts #
##############
if [[ ! "$ARCH"  =~ ^rv(32|64)[imafdgc]+$ ]]; then
    warn "Unrecognized argument for ARCH: $ARCH"
    warn "Note that only i, m, a, f, d, g, c extentions are supported" 
    help_msg 2
fi

if [[ -z $PREFIX ]]; then
    PREFIX=$PWD/$ARCH
fi

if [[ ! $JOBS =~ ^[1-9][0-9]*$ ]]; then
    warn "Unrecognized argument for N (number of concurrent jobs): $JOBS"
    help_msg 2
fi

MAKE="make -j $JOBS"
MAKEINSTALL="make install"

if [[ $ARCH =~ ^rv32 ]]; then
    XLEN=32
else
    XLEN=64
fi

[[ -z $MOD ]] && MOD=all
upd_toolchain=
upd_fesvr=
upd_sim=
upd_tests=
for mod in $MOD; do
    case $mod in
    toolchain )
        upd_toolchain=y
        upd_tests=y
        ;;
    fesvr )
        upd_fesvr=y
        ;;
    sim )
        upd_sim=y
        ;;
    tests )
        upd_tests=y
        ;;
    all )
        upd_toolchain=y
        # upd_fesvr=y
        upd_sim=y
        upd_tests=y
        ;;
    * )
        warn "Unrecoginized argument for MOD: $mod"
        help_msg 2
    esac
done

mods=$(print_mod "$MOD")
info "Target ISA:   $ARCH"
info "Install:      $mods"
info "Location:     $PREFIX"

GCC=$PREFIX/bin/riscv$XLEN-unknown-elf-gcc
# if the toolchain is already built
if [[ $upd_toolchain == 'y' && -x $GCC ]]; then
    info "Toolchain for $ARCH already installed under $PREFIX"
    info "To rebuilt from start, remove $PREFIX first"
    info "To update a single module, specified it using --update"
    exit 0
fi
if [[ $upd_toolchain != 'y' && ! -x $GCC ]]; then
    warn "You should build $(print_mod toolchain) for $ARCH before building $(print_mod $MOD)"
    warn "Omit \"--update\" option to build all tools"
    exit -1
fi

# Use the medany code model for maximum linking flexibility
CMODEL=medany

# Confirm that the user wants to install the toolchain
read -r -p "Start building? [y/N] " response
case "$response" in
    y|Y) 
        # continue
        ;;
    *)
        # abort
        exit 1
        ;;
esac
echo

##################
# Start building #
##################
export RISCV=$PREFIX
mkdir -p $RISCV
export PATH=$RISCV/bin:$PATH

# download <user/repo> in the current directory
# e.g. download "riscv/riscv-gnu-toolchain"
# TODO: it's better to include repo as submodules?
download ()
{
    local repo=$1
    local name=${1##*/} # get suffix
    local commit=$2
    local cwd=$PWD

    if [[ -z $name ]]; then
        warn "Invalid repo location: $repo"
        exit -1
    fi

    info "Check $repo"
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

cwd=$PWD

if [[ -n $upd_toolchain ]]; then
    download riscv/riscv-gnu-toolchain
    # Build riscv-gnu-toolchain, for both baremetal and linux
    BUILD_DIR=$(realpath ./build-riscv-gnu-toolchain)
    LOG_FILE=$BUILD_DIR/riscv-gnu-toolchain.log
    [[ -d $BUILD_DIR ]] && rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    info "Building riscv-gnu-toolchain... (writing output to $LOG_FILE)"
    ../riscv-gnu-toolchain/configure --prefix=$RISCV --with-arch=$ARCH --with-cmodel=$CMODEL &> $LOG_FILE
    $MAKE &>> $LOG_FILE
    info "Built toolchain for baremetal"
    $MAKE linux -j $JOBS &>> $LOG_FILE
    info "Built toolchain for linux"
    echo
    cd $cwd
    sleep 1
fi

if [[ -n $upd_fesvr ]]; then
    download csail-csg/riscv-fesvr
    # Build riscv-fesvr
    LOG_FILE=$LOG_PATH/riscv-fesvr.log
    info "Building riscv-fesvr... (writing output to $LOG_FILE)"
    cd $RISCV
    mkdir build-fesvr
    cd build-fesvr
    ../riscv-fesvr/configure --prefix=$RISCV &> $LOG_FILE
    $MAKE &>> $LOG_FILE
    $MAKEINSTALL &>> $LOG_FILE
    info "Built riscv-isa-sim"
    echo
fi

if [[ -n $upd_sim ]]; then
    download riscv/riscv-isa-sim
    # Build spike simulator for riscv
    BUILD_DIR=$(realpath ./build-riscv-isa-sim)
    LOG_FILE=$BUILD_DIR/riscv-isa-sim.log
    [[ -d $BUILD_DIR ]] && rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    info "Building riscv-isa-sim... (writing output to $LOG_FILE)"
    ../riscv-isa-sim/configure --prefix=$RISCV --enable-commitlog --with-isa=$ARCH &> $LOG_FILE
    $MAKE &>> $LOG_FILE
    $MAKEINSTALL &>> $LOG_FILE
    info "Built riscv-isa-sim"
    echo
    cd $cwd
    sleep 1
fi

if [[ -n $upd_tests ]]; then
    download riscv/riscv-tests
    # Build riscv-tests
    SRC_DIR=$(realpath ./riscv-tests)
    BUILD_DIR=$(realpath ./build-riscv-tests)
    LOG_FILE=$BUILD_DIR/riscv-tests.log
    [[ -d $BUILD_DIR ]] && rm -rf $BUILD_DIR
    mkdir -p $BUILD_DIR
    cd $BUILD_DIR
    info "Building riscv-tests... (writing output to $LOG_FILE)"
    autoconf $SRC_DIR/configure.ac > $SRC_DIR/configure && ../riscv-tests/configure --prefix=$RISCV --with-xlen=$XLEN &> $LOG_FILE
    # This may fail since some riscv-tests require ISA extensions
    # Also there is an issue with building 32-bit executables when gcc is
    # configured with --with-arch=<isa>
    # TODO: no failure is observed
    $MAKE &>> $LOG_FILE
    $MAKEINSTALL &>> $LOG_FILE
    info "Built riscv-tests"
    echo
    cd $cwd
    sleep 1
fi

if [[ -n $upd_toolchain ]]; then
    setup_script=$(realpath setup_$ARCH.sh)
    echo "#!/bin/bash
    export RISCV=$RISCV
    export PATH=\$RISCV/bin:\$PATH
    export XCOMPILE_ELF=riscv$XLEN-unknown-elf-
    export XCOMPILE_LINUX=riscv$XLEN-unknown-linux-gnu-
    # export LD_LIBRARAY_PATH=\$RISCV/lib:\$LD_LIBRARAY_PATH
    " > $setup_script
    info "Environment setup script for $ARCH generated: $setup_script"
fi

