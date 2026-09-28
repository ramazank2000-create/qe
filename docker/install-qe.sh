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

if [ -d "${QE_ROOT}/external/wannier90" ]; then
  rm -rf "${QE_ROOT}/external/wannier90/.git"
  touch "${QE_ROOT}/external/wannier90/.git"
fi

# ELPA OpenMP builds libelpa_openmp.so; modules live under include/elpa-*/modules
ELPA_INC="$(ls -d "${ELPA_PREFIX}"/include/elpa*/modules 2>/dev/null | head -1 || true)"
ELPA_LIB="$(ls "${ELPA_PREFIX}"/lib/libelpa_openmp.so "${ELPA_PREFIX}"/lib/libelpa.so \
  "${ELPA_PREFIX}"/lib/libelpa_openmp.a "${ELPA_PREFIX}"/lib/libelpa.a 2>/dev/null | head -1 || true)"
# API year 2018 covers ELPA releases 2018.11+
ELPA_API_YEAR=2018

# HDF5 parallel (Ubuntu libhdf5-openmpi-dev)
HDF5_ROOT=""
for c in /usr/lib/x86_64-linux-gnu/hdf5/openmpi /usr; do
  if [ -f "${c}/include/hdf5.h" ] || [ -f /usr/include/hdf5/openmpi/hdf5.h ]; then
    HDF5_ROOT="$c"
    break
  fi
done
# Prefer h5pcc wrapper on PATH
if command -v h5pcc.openmpi >/dev/null 2>&1 && [ ! -e /usr/local/bin/h5pcc ]; then
  ln -sfn "$(command -v h5pcc.openmpi)" /usr/local/bin/h5pcc
fi
if command -v h5pfc.openmpi >/dev/null 2>&1 && [ ! -e /usr/local/bin/h5fc ]; then
  ln -sfn "$(command -v h5pfc.openmpi)" /usr/local/bin/h5fc
fi

export BLAS_LIBS="-lopenblas"
export LAPACK_LIBS="-lopenblas"
export SCALAPACK_LIBS="-lscalapack-openmpi -lopenblas"
export LDFLAGS="-L${OPENMPI_PREFIX}/lib -L${ELPA_PREFIX}/lib -L/usr/lib/x86_64-linux-gnu ${LDFLAGS:-}"

CFG_ARGS=(
  MPIF90=mpif90
  CC=mpicc
  F90=mpif90
  --enable-parallel
  --enable-openmp
  --with-scalapack=yes
  --with-libxc=yes
  --with-libxc-prefix=/usr
  BLAS_LIBS="${BLAS_LIBS}"
  LAPACK_LIBS="${LAPACK_LIBS}"
  SCALAPACK_LIBS="${SCALAPACK_LIBS}"
)

if [ -n "${ELPA_INC}" ] && [ -n "${ELPA_LIB}" ]; then
  echo "ELPA include=${ELPA_INC} lib=${ELPA_LIB}"
  CFG_ARGS+=(
    --with-elpa-include="${ELPA_INC}"
    --with-elpa-lib="${ELPA_LIB}"
    --with-elpa-version="${ELPA_API_YEAR}"
  )
fi

# HDF5: Debian/Ubuntu openmpi layout is split include/lib — pass both if needed
if [ -d /usr/lib/x86_64-linux-gnu/hdf5/openmpi ] && [ -d /usr/include/hdf5/openmpi ]; then
  CFG_ARGS+=(
    --with-hdf5=/usr/lib/x86_64-linux-gnu/hdf5/openmpi
    --with-hdf5-include=/usr/include/hdf5/openmpi
    --with-hdf5-libs="-L/usr/lib/x86_64-linux-gnu/hdf5/openmpi -lhdf5hl_fortran -lhdf5_fortran -lhdf5_hl -lhdf5 -lz"
  )
elif [ -n "${HDF5_ROOT}" ]; then
  CFG_ARGS+=(--with-hdf5="${HDF5_ROOT}")
else
  CFG_ARGS+=(--with-hdf5=yes)
fi

./configure "${CFG_ARGS[@]}" || {
  echo "configure failed; dumping config.log tail" >&2
  tail -100 config.log || true
  exit 1
}

echo "=== make.inc feature check ==="
grep -E '^DFLAGS|^SCALAPACK_LIBS|^HDF5_LIBS|^LIBXC|^BLAS_LIBS' make.inc || true
# Require parallel + libxc at minimum; warn on missing ELPA/HDF5/ScaLAPACK then fail hard
DFLAGS="$(grep '^DFLAGS' make.inc | head -1)"
echo "$DFLAGS"
echo "$DFLAGS" | grep -q '__MPI' || { echo "FAIL: MPI not enabled"; exit 1; }
echo "$DFLAGS" | grep -q '__LIBXC' || { echo "FAIL: libxc not enabled"; exit 1; }
SCALA="$(grep '^SCALAPACK_LIBS' make.inc | head -1)"
echo "$SCALA"
echo "$SCALA" | grep -q 'scalapack' || { echo "FAIL: ScaLAPACK libs empty"; exit 1; }
echo "$DFLAGS" | grep -q '__ELPA' || { echo "FAIL: ELPA not enabled in DFLAGS"; exit 1; }
echo "$DFLAGS" | grep -q '__HDF5' || { echo "FAIL: HDF5 not enabled in DFLAGS"; exit 1; }

echo "=== Building Quantum ESPRESSO (make all) ==="
NPROC="$(nproc 2>/dev/null || echo 4)"
JOBS=$(( NPROC > 8 ? 8 : NPROC ))
if ! make all -j"${JOBS}"; then
  echo "Parallel build hit a race; retrying serially..."
  make all -j1
fi

echo "=== Building Wannier90 / pw2wannier90 ==="
make w90 -j"${JOBS}" 2>/dev/null || make wannier90 -j"${JOBS}" 2>/dev/null || true
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
