#!/bin/bash
set -euo pipefail

source /home/qe/.bashrc

export QE_ROOT="${QE_ROOT:-/opt/qe-7.5}"
export HOME="${HOME:-/home/qe}"

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
echo "Example MPI run (2 processes):"
echo "  cd ~/jobs_qe/deneme && mpirun -np 2 pw.x -nk 1 < si.scf.in > si.mpi.out"
echo ""
echo "Example ASE/Python run:"
echo "  cd ~/jobs_qe/ase_deneme && python3 si_scf.py"

exec tail -f /dev/null
