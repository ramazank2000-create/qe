#!/bin/bash
# Build HDF5 with Fortran + parallel (MPI) support for Quantum ESPRESSO.
set -euo pipefail

HDF5_VERSION="${HDF5_VERSION:-1.14.5}"
HDF5_PREFIX="${HDF5_PREFIX:-/usr/local/hdf5-${HDF5_VERSION}}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-/usr/local/openmpi-4.1.8}"
export PATH="${OPENMPI_PREFIX}/bin:${PATH}"
export CC=mpicc FC=mpif90 F9X=mpif90 CXX=mpicxx

WORKDIR="/tmp/hdf5-build"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

TARBALL="hdf5-${HDF5_VERSION}.tar.gz"
# Tag form: 1.14.5 → hdf5_1.14.5 (underscores only between major parts for GitHub releases)
TAG="hdf5_${HDF5_VERSION}"
URL="https://github.com/HDFGroup/hdf5/releases/download/${TAG}/hdf5-${HDF5_VERSION}.tar.gz"

echo "=== Downloading HDF5 ${HDF5_VERSION} from ${URL} ==="
if command -v curl >/dev/null 2>&1; then
  curl -fsSL -o "${TARBALL}" "${URL}"
else
  wget -q --content-disposition -O "${TARBALL}" "${URL}"
fi
tar -xzf "${TARBALL}"
SRC="$(find . -maxdepth 1 -type d \( -name 'hdf5-*' -o -name 'hdf5_*' \) | head -1)"
cd "$SRC"
if [ ! -x ./configure ]; then
  if [ -x ./autogen.sh ]; then ./autogen.sh; else autoreconf -i; fi
fi

echo "=== Configuring HDF5 (parallel + Fortran) ==="
./configure \
  --prefix="${HDF5_PREFIX}" \
  --enable-fortran \
  --enable-parallel \
  --enable-shared \
  --disable-static \
  --with-zlib \
  CC=mpicc FC=mpif90

echo "=== Building HDF5 ==="
make -j"$(nproc)"
make install

test -x "${HDF5_PREFIX}/bin/h5pcc" || test -x "${HDF5_PREFIX}/bin/h5cc"
test -f "${HDF5_PREFIX}/lib/libhdf5.so" || test -f "${HDF5_PREFIX}/lib/libhdf5_fortran.so"
"${HDF5_PREFIX}/bin/h5cc" -showconfig 2>/dev/null | head -20 || true

rm -rf "${WORKDIR}"
echo "=== HDF5 ${HDF5_VERSION} installed to ${HDF5_PREFIX} ==="
