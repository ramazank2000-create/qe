#!/bin/bash
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.5}"
cd "$QE_ROOT"

echo "=== Configuring Quantum ESPRESSO 7.5 ==="
export LC_ALL=C

# Docker build runs as root; QE's wannier90 fetch uses git in external/
git config --global --add safe.directory '*'

# Wannier90 sources are bundled in the release pack; prevent broken git fetch
rm -rf "${QE_ROOT}/external/wannier90/.git"
touch "${QE_ROOT}/external/wannier90/.git"

./configure \
    MPIF90=mpif90 \
    CC=gcc \
    --enable-parallel \
    --enable-openmp \
    --with-scalapack

echo "=== Building Quantum ESPRESSO (make all) ==="
NPROC=$(nproc 2>/dev/null || echo 4)
JOBS=$(( NPROC > 4 ? 4 : NPROC ))
if ! make all -j"${JOBS}"; then
    echo "Parallel build hit a race; retrying serially..."
    make all -j1
fi

echo "=== Verifying core executables ==="
for exe in pw.x ph.x pp.x bands.x neb.x cp.x; do
    if [[ ! -x "${QE_ROOT}/bin/${exe}" ]]; then
        echo "ERROR: ${exe} not found after compilation."
        exit 1
    fi
done

mkdir -p "${QE_ROOT}/tempdir"
echo "=== Quantum ESPRESSO installation completed successfully ==="
