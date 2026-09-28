#!/bin/bash
# Portal / image smoke: Si SCF (MPI pools + hybrid OMP) + BoltzTraP2 transport number.
# Must exit 0 as uid 1000; never set OMPI_ALLOW_RUN_AS_ROOT.
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
export PATH="${QE_ROOT}/bin:/opt/venv/bin:${PATH}"
export ESPRESSO_PSEUDO="${ESPRESSO_PSEUDO:-${QE_ROOT}/pseudo}"
export OMPI_MCA_btl_vader_single_copy_mechanism=none
export OMPI_MCA_hwloc_base_binding_policy=none
export OMP_NUM_THREADS=1
export LC_ALL=C
ulimit -s unlimited 2>/dev/null || true

WORK="${SMOKE_WORK:-/tmp/qe-smoke-$$}"
rm -rf "$WORK"
mkdir -p "$WORK/tmp"
cd "$WORK"

SI_UPF=""
for cand in Si.pbe-n-rrkjus_psl.1.0.0.UPF Si.pz-vbc.UPF Si.pbe-n-kjpaw_psl.1.0.0.UPF; do
  if [ -f "${ESPRESSO_PSEUDO}/${cand}" ]; then SI_UPF="$cand"; break; fi
done
if [ -z "$SI_UPF" ]; then
  SI_UPF="$(basename "$(ls "${ESPRESSO_PSEUDO}"/Si*.UPF 2>/dev/null | head -1)")"
fi
[ -n "$SI_UPF" ]
cp "${ESPRESSO_PSEUDO}/${SI_UPF}" .

ECUT=30
case "$SI_UPF" in *pz-vbc*) ECUT=18 ;; esac

cat > si.scf.in <<EOF
 &control
    calculation='scf',
    restart_mode='from_scratch',
    prefix='silicon',
    pseudo_dir = './',
    outdir='./tmp'
 /
 &system
    ibrav = 2, celldm(1) =10.20, nat=  2, ntyp= 1,
    ecutwfc = ${ECUT},
    occupations='smearing', smearing='gaussian', degauss=0.01
 /
 &electrons
    mixing_beta = 0.7
    conv_thr =  1.0d-8
 /
ATOMIC_SPECIES
 Si  28.086  ${SI_UPF}
ATOMIC_POSITIONS (alat)
 Si 0.00 0.00 0.00
 Si 0.25 0.25 0.25
K_POINTS automatic
  4 4 4  1 1 1
EOF

echo "=== Si SCF: mpirun -np 4 pw.x -nk 2 ==="
START=$(date +%s)
mpirun -np 4 pw.x -nk 2 < si.scf.in > si.scf.mpi4.out
END=$(date +%s)
echo "ELAPSED_MPI4=$((END-START))s"
grep -q "convergence has been achieved" si.scf.mpi4.out
E1="$(grep -E '!\s+total energy' si.scf.mpi4.out | tail -1)"
echo "TOTAL_ENERGY_MPI4: ${E1}"

echo "=== Si SCF hybrid: 2 MPI × 2 OMP ==="
export OMP_NUM_THREADS=2
START=$(date +%s)
mpirun -np 2 pw.x -nk 1 < si.scf.in > si.scf.hybrid.out
END=$(date +%s)
echo "ELAPSED_HYBRID=$((END-START))s"
grep -q "convergence has been achieved" si.scf.hybrid.out
E2="$(grep -E '!\s+total energy' si.scf.hybrid.out | tail -1)"
echo "TOTAL_ENERGY_HYBRID: ${E2}"
export OMP_NUM_THREADS=1

cat > si.nscf.in <<EOF
 &control
    calculation='nscf',
    prefix='silicon',
    pseudo_dir = './',
    outdir='./tmp'
 /
 &system
    ibrav = 2, celldm(1) =10.20, nat=  2, ntyp= 1,
    ecutwfc = ${ECUT},
    nbnd = 12,
    occupations='smearing', smearing='gaussian', degauss=0.01
 /
 &electrons
    conv_thr =  1.0d-8
 /
ATOMIC_SPECIES
 Si  28.086  ${SI_UPF}
ATOMIC_POSITIONS (alat)
 Si 0.00 0.00 0.00
 Si 0.25 0.25 0.25
K_POINTS automatic
  6 6 6  0 0 0
EOF

echo "=== Si NSCF for BoltzTraP2 ==="
mpirun -np 4 pw.x -nk 2 < si.nscf.in > si.nscf.out
test -d ./tmp/silicon.save

echo "=== BoltzTraP2 on QE save directory ==="
export OMP_NUM_THREADS="${QC_NCORES:-2}"
python3 <<'PY'
import sys
from pathlib import Path
import numpy as np

save = Path("tmp/silicon.save")
assert save.is_dir(), save

from BoltzTraP2 import dft, sphere, fite, bandlib

data = dft.DFTData(str(save), derivatives=False)
equivalences = sphere.get_equivalences(data.atoms, data.magmom, max(200, 3 * len(data.kpoints)))
lattvec = data.get_lattvec()
coeffs = fite.fitde3D(data, equivalences)
ebands, vvband, _cRTA = fite.getBTPbands(equivalences, coeffs, lattvec, curvature=False)
# BoltzTraP2 ≥26: BTPDOS returns (e, dos, vvdos, cdos)
dose, dos, vvdos, _cdos = bandlib.BTPDOS(ebands, vvband, npts=1200)
mu = bandlib.solve_for_mu(dose, dos, data.nelect, 0.0, refine=True)
idx = int(np.argmin(np.abs(dose - mu)))
# Si is gapped → DOS(μ)≈0; also report vvDOS slightly above μ (n-type probe)
idx_n = int(np.argmin(np.abs(dose - (mu + 0.05))))
def _tr(i):
    return float(np.trace(vvdos[:, :, i])) if vvdos.ndim == 3 else float(np.sum(vvdos[..., i]))
print(f"BOLTZTRAP2_EF_Ry={mu:.8f}")
print(f"BOLTZTRAP2_DOS_AT_EF={float(dos[idx]):.6e}")
print(f"BOLTZTRAP2_TRANSPORT={_tr(idx_n):.6e}")
print("BoltzTraP2 interpolate/integrate (in-memory) OK", flush=True)
PY

echo "=== SMOKE SUMMARY ==="
echo "$E1"
echo "$E2"
echo "SMOKE_QE_OK"
