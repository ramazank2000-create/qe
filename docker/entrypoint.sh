#!/bin/bash
set -euo pipefail

source /home/qe/.bashrc 2>/dev/null || true

export QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
export HOME="${HOME:-/home/qe}"
export ESPRESSO_PSEUDO="${ESPRESSO_PSEUDO:-${QE_ROOT}/pseudo}"
export OMPI_MCA_btl_vader_single_copy_mechanism=none
export OMP_NUM_THREADS="${OMP_NUM_THREADS:-1}"

mkdir -p "${HOME}/jobs_qe" "${HOME}/scratch"

if [[ $# -gt 0 ]]; then
    exec "$@"
fi

echo "Quantum ESPRESSO container ready."
echo "  QE_ROOT=${QE_ROOT}"
echo "  Jobs directory: ${HOME}/jobs_qe"
echo "  pw.x: $(which pw.x 2>/dev/null || echo 'not in PATH')"
echo "  ASE: $(python3 -c 'import ase; print(ase.__version__)' 2>/dev/null || echo 'not installed')"
echo ""
echo "Example serial run:"
echo "  cd ~/jobs_qe/deneme && mpirun -np 1 pw.x -nk 1 < si.scf.in > si.scf.out"
echo ""
echo "Example MPI run (4 processes, 2 pools):"
echo "  cd ~/jobs_qe/deneme && mpirun -np 4 pw.x -nk 2 < si.scf.in > si.mpi.out"
echo ""
echo "Example hybrid (2 MPI × 2 OpenMP):"
echo "  OMP_NUM_THREADS=2 mpirun -np 2 pw.x < si.scf.in > si.hybrid.out"
echo ""
echo "Example ASE/Python run:"
echo "  cd ~/jobs_qe/ase_deneme && python3 si_scf.py"

exec tail -f /dev/null
