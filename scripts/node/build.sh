#!/bin/bash
# Usage: node/build.sh (
#   build |
#   dependencies |
#   sodium |
#   secp |
#   blst |
#   node |
#   help [-h]
# )
#
# Info:
#
#   - build) Build the full node from source. Default value if no option is passed.
#   - dependencies) Download and install compiler dependencies.
#   - sodium) Build libsodium from source.
#   - secp) Build secp256k1 from source.
#   - blst) Build libblst from source.
#   - node) Build cardano node and cli from source.
#   - help) View this files help. Default value if no option is passed.

source "$(dirname "$0")/../common.sh"

# Private functions

_build_die() {
    print 'ERROR' "$1" $red
    return 1
}

_build_fail() {
    _build_die "$1" || return 1
}

_confirm() {
    read -p "$1 ([y]es or [N]o): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y | yes) return 0 ;;
        *) _build_fail 'Build cancelled' ;;
    esac
}

# Public functions

build_dependencies() {
    print 'BUILD' 'Install dependencies'
    sudo $PACKAGER update -y || _build_fail 'Could not update package lists' || return 1
    sudo $PACKAGER install autoconf \
                 automake \
                 build-essential \
                 curl \
                 g++ \
                 git \
                 jq \
                 libffi-dev \
                 libffi8 \
                 libffi8ubuntu1 \
                 libgmp-dev \
                 libgmp10 \
                 liblmdb-dev \
                 libncurses-dev \
                 libsodium-dev \
                 libssl-dev \
                 libsystemd-dev \
                 libtool \
                 liburing-dev \
                 libsnappy-dev \
                 make \
                 pkg-config \
                 protobuf-compiler \
                 tmux \
                 wget \
                 zlib1g-dev -y || _build_fail 'Could not install build dependencies' || return 1

    print 'BUILD' 'Installing Haskell'
    curl --proto '=https' --tlsv1.2 -sSf https://get-ghcup.haskell.org | sh || _build_fail 'Could not install ghcup' || return 1
    if [ ! -f "$NODE_HOME/../.ghcup/env" ]; then
        _build_fail 'Could not configure ghcup env, retry installation' || return 1
    fi
    source ~/.bashrc
    source "$NODE_HOME/../.ghcup/env" || _build_fail 'Could not source ghcup env' || return 1

    print 'BUILD' 'Set node build versions'
    ghcup install ghc $GHC_VERSION || _build_fail "Could not install ghc $GHC_VERSION" || return 1
    ghcup install cabal $CABAL_VERSION || _build_fail "Could not install cabal $CABAL_VERSION" || return 1
    ghcup set ghc $GHC_VERSION || _build_fail "Could not set ghc $GHC_VERSION" || return 1
    ghcup set cabal $CABAL_VERSION || _build_fail "Could not set cabal $CABAL_VERSION" || return 1
    cardano_build_lib_versions_from_node "$NODE_VERSION" || _build_fail "Could not resolve build lib versions for cardano-node $NODE_VERSION" || return 1
    print 'BUILD' "NODE_VERSION: $NODE_VERSION"
    print 'BUILD' "SODIUM_VERSION: $SODIUM_VERSION"
    print 'BUILD' "IOHKNIX_VERSION: $IOHKNIX_VERSION"
    print 'BUILD' "SECP256K1_VERSION: $SECP256K1_VERSION"
    print 'BUILD' "BLST_VERSION: $BLST_VERSION"
    _confirm 'Please confirm versions to continue (y|n)' || return 1
    print 'BUILD' 'Create directories'
    mkdir -p ~/src || _build_fail 'Could not create src directory' || return 1
    return 0
}

build_sodium() {
    print 'BUILD' "Installing sodium"
    cardano_build_lib_versions_from_node "$NODE_VERSION" || _build_fail "Could not resolve sodium version for $NODE_VERSION" || return 1
    cd ~/src || _build_fail 'Could not enter src directory' || return 1
    sudo rm -R libsodium
    git clone https://github.com/intersectmbo/libsodium || _build_fail 'Could not clone libsodium' || return 1
    cd libsodium || _build_fail 'Could not enter libsodium directory' || return 1
    git checkout $SODIUM_VERSION || _build_fail "Could not checkout libsodium $SODIUM_VERSION" || return 1
    ./autogen.sh || _build_fail 'Could not autogen libsodium' || return 1
    ./configure || _build_fail 'Could not configure libsodium' || return 1
    make || _build_fail 'Could not build libsodium' || return 1
    make check || _build_fail 'Libsodium make check failed' || return 1
    sudo make install || _build_fail 'Could not install libsodium' || return 1
    if [[ ! $LD_LIBRARY_PATH ]]; then
        print 'BUILD' "Set LD_LIBRARY_PATH and PKG_CONFIG_PATH"
        source ~/.bashrc
        sed -i '$ a\export LD_LIBRARY_PATH="/usr/local/lib:$LD_LIBRARY_PATH"' ~/.bashrc || _build_fail 'Could not update LD_LIBRARY_PATH' || return 1
        sed -i '$ a\export PKG_CONFIG_PATH="/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH"' ~/.bashrc || _build_fail 'Could not update PKG_CONFIG_PATH' || return 1
        source ~/.bashrc
    fi
    return 0
}

build_secp() {
    print 'BUILD' 'Installing secp256k1'
    cardano_build_lib_versions_from_node "$NODE_VERSION" || _build_fail "Could not resolve secp256k1 version for $NODE_VERSION" || return 1
    cd ~/src || _build_fail 'Could not enter src directory' || return 1
    sudo rm -R secp256k1
    git clone --depth 1 --branch ${SECP256K1_VERSION} https://github.com/bitcoin-core/secp256k1 || _build_fail 'Could not clone secp256k1' || return 1
    cd secp256k1 || _build_fail 'Could not enter secp256k1 directory' || return 1
    ./autogen.sh || _build_fail 'Could not autogen secp256k1' || return 1
    ./configure --enable-module-schnorrsig --enable-experimental || _build_fail 'Could not configure secp256k1' || return 1
    make || _build_fail 'Could not build secp256k1' || return 1
    make check || _build_fail 'Secp256k1 make check failed' || return 1
    sudo make install || _build_fail 'Could not install secp256k1' || return 1
    sudo ldconfig || _build_fail 'Could not run ldconfig' || return 1
    return 0
}

build_blst() {
    print 'BUILD' 'Installing blst'
    cardano_build_lib_versions_from_node "$NODE_VERSION" || _build_fail "Could not resolve blst version for $NODE_VERSION" || return 1
    cd ~/src || _build_fail 'Could not enter src directory' || return 1
    sudo rm -R blst
    print 'BUILD' "Version: $BLST_VERSION"
    git clone --depth 1 --branch ${BLST_VERSION} https://github.com/supranational/blst || _build_fail 'Could not clone blst' || return 1
    cd blst || _build_fail 'Could not enter blst directory' || return 1
    ./build.sh || _build_fail 'Could not build blst' || return 1
    cat >libblst.pc <<EOF
prefix=/usr/local
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libblst
Description: Multilingual BLS12-381 signature library
URL: https://github.com/supranational/blst
Version: ${BLST_VERSION#v}
Cflags: -I\${includedir}
Libs: -L\${libdir} -lblst
EOF
    sudo cp libblst.pc /usr/local/lib/pkgconfig/ || _build_fail 'Could not install libblst.pc' || return 1
    sudo cp bindings/blst_aux.h bindings/blst.h bindings/blst.hpp /usr/local/include/ || _build_fail 'Could not install blst headers' || return 1
    sudo cp libblst.a /usr/local/lib || _build_fail 'Could not install libblst.a' || return 1
    sudo chmod u=rw,go=r /usr/local/{lib/{libblst.a,pkgconfig/libblst.pc},include/{blst.{h,hpp},blst_aux.h}} || _build_fail 'Could not set blst file permissions' || return 1
    return 0
}

build_node() {
    print 'BUILD' "Installing cardano node $NODE_VERSION"
    cd ~/src || _build_fail 'Could not enter src directory' || return 1
    sudo rm -R cardano-node
    git clone https://github.com/intersectmbo/cardano-node.git || _build_fail 'Could not clone cardano-node' || return 1
    cd cardano-node || _build_fail 'Could not enter cardano-node directory' || return 1
    git fetch --all --recurse-submodules --tags || _build_fail 'Could not fetch cardano-node tags' || return 1
    git checkout tags/$NODE_VERSION || _build_fail "Could not checkout cardano-node $NODE_VERSION" || return 1
    echo "with-compiler: ghc-$GHC_VERSION" >>cabal.project.local || _build_fail 'Could not write cabal.project.local' || return 1
    source ~/.bashrc
    cabal update || _build_fail 'Could not run cabal update' || return 1
    cabal build all || _build_fail 'Could not build cardano-node' || return 1
    cabal build cardano-cli || _build_fail 'Could not build cardano-cli' || return 1

    print 'BUILD' 'Copy files to the bin and add to $PATH'
    mkdir -p "$BIN_PATH" || _build_fail 'Could not create bin path' || return 1
    cp -p "$(./scripts/bin-path.sh cardano-node)" "$BIN_PATH/" || _build_fail 'Could not copy cardano-node binary' || return 1
    cp -p "$(./scripts/bin-path.sh cardano-cli)" "$BIN_PATH/" || _build_fail 'Could not copy cardano-cli binary' || return 1
    if [[ ":$PATH:" != *":$BIN_PATH:"* ]]; then
        sed -i '$ a\export PATH="$PATH:'"$BIN_PATH"'"' ~/.bashrc || _build_fail 'Could not update PATH in bashrc' || return 1
    fi
    source ~/.bashrc
    return 0
}

build() {
    build_dependencies || return 1
    build_sodium || return 1
    build_secp || return 1
    build_blst || return 1
    build_node || return 1
    $CNNODE --version || _build_fail 'Built cardano-node binary is not runnable' || return 1
    $CNCLI --version || _build_fail 'Built cardano-cli binary is not runnable' || return 1
    print 'BUILD' 'Complete building cardano-cli cardano-node' $green
    return 0
}

case $1 in
    build) build ;;
    dependencies) build_dependencies ;;
    sodium) build_sodium ;;
    secp) build_secp ;;
    blst) build_blst ;;
    node) build_node ;;
    help) help "${2:-"--help"}" ;;
    *) build ;;
esac
exit $?
