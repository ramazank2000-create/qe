#!/bin/bash
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
USER_HOME="/home/qe"

mkdir -p "$USER_HOME/jobs_qe" "$USER_HOME/scratch"
chown -R qe:qe "$USER_HOME"

cat > "$USER_HOME/.bashrc" <<EOF
# Quantum ESPRESSO user environment
export QE_ROOT=${QE_ROOT}
export ESPRESSO_PSEUDO=\${ESPRESSO_PSEUDO:-\${QE_ROOT}/pseudo}
export PATH=\${QE_ROOT}/bin:/docker:\${PATH}
export SCRATCH=${USER_HOME}/scratch
# MPI codes: default 1 OpenMP thread; raise for hybrid runs.
export OMP_NUM_THREADS=\${OMP_NUM_THREADS:-1}
export LC_ALL=C
export OMPI_MCA_btl_vader_single_copy_mechanism=none
export OMPI_MCA_hwloc_base_binding_policy=none

# Parallel launch prefix — set -np yourself (no hardcoded process count).
# Example: PARA_PREFIX="mpirun -np 4" PARA_POSTFIX="-nk 2"
export PARA_PREFIX="\${PARA_PREFIX:-mpirun}"
export PARA_POSTFIX="\${PARA_POSTFIX:--nk 1}"

alias cdj='cd ${USER_HOME}/jobs_qe'
alias qe-pw='pw.x'
alias qe-ph='ph.x'
alias qe-pp='pp.x'
alias qe-ase='python3'

ulimit -s unlimited 2>/dev/null || true
EOF

chown qe:qe "$USER_HOME/.bashrc"
