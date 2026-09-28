#!/bin/bash
# Build ELPA (Eigenvalue SoLvers for Petaflop Applications) for QE.
set -euo pipefail

ELPA_VERSION="${ELPA_VERSION:-2024.05.001}"
ELPA_PREFIX="${ELPA_PREFIX:-/usr/local/elpa-${ELPA_VERSION}}"
ELPA_TARBALL="elpa-${ELPA_VERSION}.tar.gz"
ELPA_URL="https://elpa.mpcdf.mpg.de/software/tarball-archive/Releases/${ELPA_VERSION}/${ELPA_TARBALL}"

OPENMPI_PREFIX="${OPENMPI_PREFIX:-/usr/local/openmpi-4.1.8}"
export PATH="${OPENMPI_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${OPENMPI_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
export FC=mpif90 CC=mpicc CXX=mpicxx

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential gfortran wget ca-certificates \
  libopenblas-dev libscalapack-openmpi-dev
rm -rf /var/lib/apt/lists/*

WORKDIR="/tmp/elpa-build"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "=== Downloading ELPA ${ELPA_VERSION} ==="
wget -q "${ELPA_URL}" -O "${ELPA_TARBALL}"
tar -xzf "${ELPA_TARBALL}"
cd "elpa-${ELPA_VERSION}"

echo "=== Configuring ELPA ==="
mkdir -p build && cd build
# Ubuntu 22.04 mpicc may fail ELPA's SSE3 intrinsic probe; disable SSE kernels.
../configure \
  --prefix="${ELPA_PREFIX}" \
  --enable-openmp \
  --disable-avx \
  --disable-avx2 \
  --disable-avx512 \
  --disable-sse \
  --disable-sse-assembly \
  FC=mpif90 CC=mpicc CXX=mpicxx \
  SCALAPACK_LDFLAGS="-lscalapack-openmpi -lopenblas" \
  SCALAPACK_FCFLAGS="-I/usr/include" \
  CFLAGS="-O3" FCFLAGS="-O3"

echo "=== Building ELPA ==="
make -j"$(nproc)"
make install

test -f "${ELPA_PREFIX}/lib/libelpa.so" || test -f "${ELPA_PREFIX}/lib/libelpa.a" \
  || ls "${ELPA_PREFIX}/lib"/libelpa* 

rm -rf "${WORKDIR}"
echo "=== ELPA ${ELPA_VERSION} installed to ${ELPA_PREFIX} ==="
