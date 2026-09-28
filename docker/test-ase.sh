#!/bin/bash
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
export LC_ALL=C
export PATH="${QE_ROOT}/bin:${PATH}"
export OMPI_MCA_btl_vader_single_copy_mechanism=none
export OMPI_MCA_hwloc_base_binding_policy=none
export OMP_NUM_THREADS=1

# Build-time may be root; never set OMPI_ALLOW_RUN_AS_ROOT env vars.
# ASE shells out to mpirun — wrap it with --allow-run-as-root only when uid==0.
if [ "$(id -u)" -eq 0 ]; then
  WRAP=/tmp/mpirun-wrap-$$
  mkdir -p "$WRAP"
  cat > "$WRAP/mpirun" <<'EOF'
#!/bin/bash
exec "$(dirname "$(command -v -p mpirun 2>/dev/null || true)")/mpirun" --allow-run-as-root "$@" 2>/dev/null \
  || exec /usr/local/openmpi-4.1.8/bin/mpirun --allow-run-as-root "$@" \
  || exec "$(type -P mpirun)" --allow-run-as-root "$@"
EOF
  # Prefer real binary path
  REAL_MPIRUN="$(command -v mpirun)"
  cat > "$WRAP/mpirun" <<EOF
#!/bin/bash
exec "${REAL_MPIRUN}" --allow-run-as-root "\$@"
EOF
  chmod +x "$WRAP/mpirun"
  export PATH="$WRAP:$PATH"
fi

echo "=== ASE import check ==="
python3 - <<'PY'
import ase
import qe_ase
from qe_ase import make_espresso_calc, mpi_command, write_pw_input

print(f"OK: ASE {ase.__version__}")
print(f"OK: qe_ase {qe_ase.__version__ if hasattr(qe_ase, '__version__') else 'installed'}")
print(f"OK: MPI command -> {mpi_command(np=1, nk=1)}")
PY

echo "=== ASE Si SCF test (gamma, 1 MPI rank) ==="
TEST_WORK=/tmp/qe_ase_test
rm -rf "${TEST_WORK}"
mkdir -p "${TEST_WORK}/tmp"
cp "${QE_ROOT}/atomic/examples/pseudo-LDA-0.5/Si.pz-vbc.UPF" "${TEST_WORK}/"

python3 - <<'PY'
import os
from pathlib import Path

from ase.build import bulk
from qe_ase import make_espresso_calc, write_pw_input

work = Path("/tmp/qe_ase_test")
os.chdir(work)

atoms = bulk("Si", "diamond", a=5.43, cubic=True)
input_data = {
    "control": {
        "calculation": "scf",
        "prefix": "silicon",
        "pseudo_dir": "./",
        "outdir": "./tmp",
    },
    "system": {"ecutwfc": 18.0},
    "electrons": {"mixing_beta": 0.7, "conv_thr": 1.0e-8},
}
pseudopotentials = {"Si": "Si.pz-vbc.UPF"}

write_pw_input("si.ase.in", atoms, input_data=input_data, pseudopotentials=pseudopotentials, kpts=None)

calc = make_espresso_calc(
    atoms,
    directory=str(work),
    pseudo_dir=work,
    pseudopotentials=pseudopotentials,
    input_data=input_data,
    kpts=None,
    mpi_np=1,
    mpi_nk=1,
)
atoms.calc = calc
energy = atoms.get_potential_energy()
print(f"OK: ASE SCF energy = {energy:.6f} eV")
PY

if [[ ! -f "${TEST_WORK}/espresso.pwo" ]]; then
    echo "FAIL: ASE did not produce espresso.pwo"
    exit 1
fi
if ! grep -q "convergence has been achieved" "${TEST_WORK}/espresso.pwo"; then
    echo "FAIL: ASE SCF did not converge"
    tail -40 "${TEST_WORK}/espresso.pwo"
    exit 1
fi

echo "=== ASE integration tests passed ==="
