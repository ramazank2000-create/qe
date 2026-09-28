#!/bin/bash
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
export LC_ALL=C
export PATH="${QE_ROOT}/bin:${PATH}"
export OMPI_MCA_btl_vader_single_copy_mechanism=none
export OMPI_MCA_hwloc_base_binding_policy=none
export OMP_NUM_THREADS=1
# Build-time tests may run as root in Dockerfile; never export OMPI_ALLOW_RUN_AS_ROOT.
# Use --allow-run-as-root only for this build-time check if uid==0.
MPIRUN=(mpirun)
if [ "$(id -u)" -eq 0 ]; then
  MPIRUN=(mpirun --allow-run-as-root)
fi

echo "=== QE build verification ==="

for exe in pw.x ph.x pp.x bands.x neb.x cp.x; do
    if [[ ! -x "${QE_ROOT}/bin/${exe}" ]]; then
        echo "FAIL: ${exe} missing"
        exit 1
    fi
    echo "OK: ${exe}"
done

echo "=== MPI check ==="
which mpirun
mpirun --version | head -1

echo "=== pw.x version ==="
"${MPIRUN[@]}" -np 1 pw.x -v 2>&1 | head -3 || true

echo "=== Quick Si SCF test (1 MPI rank) ==="
TEST_WORK=/tmp/qe_build_test
rm -rf "${TEST_WORK}"
mkdir -p "${TEST_WORK}/tmp"
cp "${QE_ROOT}/atomic/examples/pseudo-LDA-0.5/Si.pz-vbc.UPF" "${TEST_WORK}/"
cat > "${TEST_WORK}/si.scf.in" <<'EOF'
 &control
    calculation='scf',
    restart_mode='from_scratch',
    prefix='silicon',
    pseudo_dir = './',
    outdir='./tmp'
 /
 &system
    ibrav = 2, celldm(1) =10.20, nat=  2, ntyp= 1,
    ecutwfc = 18.0
 /
 &electrons
    mixing_beta = 0.7
    conv_thr =  1.0d-8
 /
ATOMIC_SPECIES
 Si  28.086  Si.pz-vbc.UPF
ATOMIC_POSITIONS (alat)
 Si 0.00 0.00 0.00
 Si 0.25 0.25 0.25
K_POINTS {gamma}
EOF

cd "${TEST_WORK}"
"${MPIRUN[@]}" -np 1 pw.x -nk 1 < si.scf.in > si.scf.out
if ! grep -q "convergence has been achieved" si.scf.out; then
    echo "FAIL: Si SCF did not converge"
    tail -40 si.scf.out
    exit 1
fi
echo "OK: Si SCF converged (1 rank)"

echo "=== Quick Si SCF test (2 MPI ranks) ==="
"${MPIRUN[@]}" -np 2 pw.x -nk 1 < si.scf.in > si.mpi.out
if ! grep -q "convergence has been achieved" si.mpi.out; then
    echo "FAIL: MPI Si SCF did not converge"
    tail -40 si.mpi.out
    exit 1
fi
echo "OK: Si SCF converged (2 ranks)"

echo "=== All build-time tests passed ==="
