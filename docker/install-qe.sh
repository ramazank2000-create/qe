#!/bin/bash
# Configure and build Quantum ESPRESSO 7.6 with MPI+OpenMP, ScaLAPACK, ELPA, libxc, HDF5, Wannier90, EPW.
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
OPENMPI_PREFIX="${OPENMPI_PREFIX:-/usr/local/openmpi-4.1.8}"
ELPA_PREFIX="${ELPA_PREFIX:-/usr/local/elpa-2024.05.001}"

export PATH="${OPENMPI_PREFIX}/bin:${PATH}"
export LD_LIBRARY_PATH="${OPENMPI_PREFIX}/lib:${ELPA_PREFIX}/lib:${LD_LIBRARY_PATH:-}"
export LC_ALL=C
export FC=mpif90 F90=mpif90 CC=mpicc CXX=mpicxx

cd "$QE_ROOT"

echo "=== Configuring Quantum ESPRESSO 7.6 ==="
git config --global --add safe.directory '*' 2>/dev/null || true

# Wannier90 sources are bundled; prevent broken git fetch in external/
if [ -d "${QE_ROOT}/external/wannier90" ]; then
  rm -rf "${QE_ROOT}/external/wannier90/.git"
  touch "${QE_ROOT}/external/wannier90/.git"
fi

# ELPA module / library paths (versioned include dir, e.g. include/elpa-2024.05.001)
ELPA_INC="$(ls -d "${ELPA_PREFIX}"/include/elpa* 2>/dev/null | head -1 || true)"
ELPA_LIB="$(ls "${ELPA_PREFIX}"/lib/libelpa.so* "${ELPA_PREFIX}"/lib/libelpa.a 2>/dev/null | head -1 || true)"
# ELPA API year for QE configure: 2018 covers ELPA releases 2018.11 and beyond
ELPA_API_YEAR=2018

CFG_ARGS=(
  MPIF90=mpif90
  CC=mpicc
  F90=mpif90
  --enable-parallel
  --enable-openmp
  --with-scalapack=yes
  --with-hdf5=yes
  --with-libxc=yes
  --with-libxc-prefix=/usr
)

if [ -n "${ELPA_INC}" ] && [ -n "${ELPA_LIB}" ]; then
  CFG_ARGS+=(
    --with-elpa-include="${ELPA_INC}"
    --with-elpa-lib="${ELPA_LIB}"
    --with-elpa-version="${ELPA_API_YEAR}"
  )
  export LDFLAGS="-L${ELPA_PREFIX}/lib -L${OPENMPI_PREFIX}/lib ${LDFLAGS:-}"
  export LIBS="-lelpa -lscalapack-openmpi -lopenblas ${LIBS:-}"
fi

./configure "${CFG_ARGS[@]}" || {
  echo "configure with ELPA/libxc/HDF5 failed; dumping config.log tail" >&2
  tail -80 config.log || true
  exit 1
}

# Confirm key features in make.inc
grep -E 'DFLAGS|HDF5|ELPA|LIBXC|SCALAPACK|OMP' make.inc | head -40 || true

echo "=== Building Quantum ESPRESSO (make all) ==="
NPROC="$(nproc 2>/dev/null || echo 4)"
JOBS=$(( NPROC > 8 ? 8 : NPROC ))
if ! make all -j"${JOBS}"; then
  echo "Parallel build hit a race; retrying serially..."
  make all -j1
fi

echo "=== Building Wannier90 interface / pw2wannier90 (if not in all) ==="
make w90 -j"${JOBS}" 2>/dev/null || make wannier90 -j"${JOBS}" 2>/dev/null || true
# pw2wannier90 ships with PP
test -x "${QE_ROOT}/bin/pw2wannier90.x" || make -C PP pw2wannier90 -j"${JOBS}" 2>/dev/null || true

echo "=== Building EPW (best-effort) ==="
EPW_OK=0
if make epw -j"${JOBS}"; then
  EPW_OK=1
elif make -C EPW all -j"${JOBS}"; then
  EPW_OK=1
else
  echo "WARNING: EPW build failed; continuing without epw.x" >&2
fi

echo "=== Verifying core executables ==="
for exe in pw.x ph.x pp.x bands.x neb.x cp.x; do
  if [[ ! -x "${QE_ROOT}/bin/${exe}" ]]; then
    echo "ERROR: ${exe} not found after compilation."
    exit 1
  fi
done
for exe in wannier90.x pw2wannier90.x; do
  if [[ -x "${QE_ROOT}/bin/${exe}" ]]; then
    echo "OK: ${exe}"
  else
    echo "WARNING: ${exe} missing"
  fi
done
if [[ "${EPW_OK}" -eq 1 ]] && [[ -x "${QE_ROOT}/bin/epw.x" ]]; then
  echo "OK: epw.x"
else
  echo "NOTE: epw.x not installed"
fi

mkdir -p "${QE_ROOT}/tempdir" "${QE_ROOT}/pseudo"
echo "=== Quantum ESPRESSO installation completed successfully ==="
