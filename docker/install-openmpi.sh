#!/bin/bash
# Build OpenMPI with PMIx (internal) + Slurm PMI support for HPC srun --mpi=pmix.
set -euo pipefail

OPENMPI_VERSION="${OPENMPI_VERSION:-4.1.8}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-/usr/local/openmpi-${OPENMPI_VERSION}}"
OPENMPI_TARBALL="openmpi-${OPENMPI_VERSION}.tar.bz2"
OPENMPI_URL="https://download.open-mpi.org/release/open-mpi/v${OPENMPI_VERSION%.*}/${OPENMPI_TARBALL}"

export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential gfortran wget ca-certificates \
  libpmix-dev libevent-dev libhwloc-dev zlib1g-dev \
  libslurm-dev libpmi2-0-dev
rm -rf /var/lib/apt/lists/*

WORKDIR="/tmp/openmpi-build"
rm -rf "${WORKDIR}"
mkdir -p "${WORKDIR}"
cd "${WORKDIR}"

echo "=== Downloading OpenMPI ${OPENMPI_VERSION} ==="
wget -q "${OPENMPI_URL}" -O "${OPENMPI_TARBALL}"
tar -xjf "${OPENMPI_TARBALL}"
cd "openmpi-${OPENMPI_VERSION}"

echo "=== Configuring OpenMPI (PMIx internal + Slurm) ==="
./configure \
  --prefix="${OPENMPI_PREFIX}" \
  --with-pmix=internal \
  --with-slurm \
  --with-pmi \
  --disable-builtin-atomics \
  --enable-mpi1-compatibility

echo "=== Building OpenMPI ==="
make -j"$(nproc)"
make install

echo "=== Verifying OpenMPI ==="
"${OPENMPI_PREFIX}/bin/mpirun" --version | head -n 1
ompi_info --parsable 2>/dev/null | grep -E 'pmix|slurm|pmi' | head -20 || true
test -x "${OPENMPI_PREFIX}/bin/mpirun"

rm -rf "${WORKDIR}"
echo "=== OpenMPI ${OPENMPI_VERSION} installed to ${OPENMPI_PREFIX} ==="
