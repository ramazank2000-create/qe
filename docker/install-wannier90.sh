#!/bin/bash
# Wannier90 3.1.0 (wannier90.x, postw90.x; MPI) with the image's gfortran + OpenMPI 4.1.8 + OpenBLAS → /opt/wannier90-3.1.0,
# linked into /usr/local/bin. QE's pw2wannier90.x is already in /opt/qe-7.6/bin (install-qe.sh); the QE tree is not touched.
set -euo pipefail

W90_VERSION="${W90_VERSION:-3.1.0}"
W90_SHA256="${W90_SHA256:-40651a9832eb93dec20a8360dd535262c261c34e13c41b6755fa6915c936b254}"
W90_PREFIX="/opt/wannier90-${W90_VERSION}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-/usr/local/openmpi-4.1.8}"
export PATH="${OPENMPI_PREFIX}/bin:${PATH}"

WORKDIR="$(mktemp -d)"
cd "${WORKDIR}"
echo "=== Downloading Wannier90 ${W90_VERSION} ==="
curl -fsSL --retry 3 -o w90.tgz "https://github.com/wannier-developers/wannier90/archive/v${W90_VERSION}.tar.gz"
echo "${W90_SHA256}  w90.tgz" | sha256sum -c -
tar --no-same-owner -xzf w90.tgz
cd "wannier90-${W90_VERSION}"

# gfortran >= 10 rejects the type-generic MPI calls of comms.F90 without -fallow-argument-mismatch.
# -fno-inline-arg-packing: 3.1.0 passes root-only (unallocated on other ranks) arrays to comms_scatterv; the inlined
# packing of gfortran >= 10 at -O2 segfaults there on rank > 0 (overlap.F90:207). Verified 2026-10-12: GaAs / Pb
# (disentanglement) spreads and postw90 DOS identical on 1, 2 and 4 ranks.
cat > make.inc <<'EOF'
F90 = gfortran
COMMS = mpi
MPIF90 = mpif90
FCOPTS = -O2 -fno-inline-arg-packing -fallow-argument-mismatch
LDOPTS =
LIBS = -lopenblas
EOF

echo "=== Building wannier90.x + postw90.x ==="
make default

mkdir -p "${W90_PREFIX}/bin" "${W90_PREFIX}/examples/example01"
install -m755 wannier90.x postw90.x "${W90_PREFIX}/bin/"
# GaAs tutorial (amn/mmn shipped, no plotting) for the smoke test
cp examples/example01/gaas.win examples/example01/gaas.amn examples/example01/gaas.mmn "${W90_PREFIX}/examples/example01/"
cp LICENSE "${W90_PREFIX}/"
ln -sf "${W90_PREFIX}/bin/wannier90.x" "${W90_PREFIX}/bin/postw90.x" /usr/local/bin/

ldd "${W90_PREFIX}/bin/wannier90.x" | grep -E 'mpi|openblas'
cd / && rm -rf "${WORKDIR}"
echo "=== Wannier90 ${W90_VERSION} installed to ${W90_PREFIX} ==="
