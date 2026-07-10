#!/bin/bash
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.5}"
USER_HOME="/home/qe"

mkdir -p "$USER_HOME/jobs_qe" "$USER_HOME/scratch"
chown -R qe:qe "$USER_HOME"

cat > "$USER_HOME/.bashrc" <<EOF
# Quantum ESPRESSO user environment
export QE_ROOT=${QE_ROOT}
export ESPRESSO_PSEUDO=\${QE_ROOT}/pseudo
export PATH=\${QE_ROOT}/bin:/docker:\${PATH}
export SCRATCH=${USER_HOME}/scratch
export OMP_NUM_THREADS=\${OMP_NUM_THREADS:-4}
export LC_ALL=C

# MPI parallel launch (edit -np for your run)
export PARA_PREFIX="mpirun -np 2"
export PARA_POSTFIX="-nk 1 -nd 1 -nb 1 -nt 1"

alias cdj='cd ${USER_HOME}/jobs_qe'
alias qe-pw='pw.x'
alias qe-ph='ph.x'
alias qe-pp='pp.x'
alias qe-ase='python3'

ulimit -s unlimited 2>/dev/null || true
EOF

chown qe:qe "$USER_HOME/.bashrc"
