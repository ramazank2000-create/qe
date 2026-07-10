#!/usr/bin/env python3
"""Silicon SCF hesabi - ASE + Quantum ESPRESSO ornegi."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

from ase.build import bulk
from qe_ase import make_espresso_calc, write_pw_input

JOB_DIR = Path(__file__).resolve().parent
PSEUDO = "Si.pz-vbc.UPF"
QE_ROOT = Path(os.environ.get("QE_ROOT", "/opt/qe-7.5"))
PSEUDO_SOURCES = [
    JOB_DIR / PSEUDO,
    JOB_DIR.parent / "deneme" / PSEUDO,
    QE_ROOT / "atomic/examples/pseudo-LDA-0.5" / PSEUDO,
    Path(os.environ.get("ESPRESSO_PSEUDO", QE_ROOT / "pseudo")) / PSEUDO,
]


def ensure_pseudo() -> Path:
    dest = JOB_DIR / PSEUDO
    if not dest.exists():
        for src in PSEUDO_SOURCES:
            if src.exists():
                shutil.copy(src, dest)
                break
        else:
            raise FileNotFoundError(
                f"{PSEUDO} bulunamadi. jobs_qe/deneme/ klasorune kopyalayin "
                f"veya container icindeki {QE_ROOT}/pseudo/ yolunu kullanin."
            )
    return JOB_DIR


def main() -> None:
    pseudo_dir = ensure_pseudo()
    os.chdir(JOB_DIR)
    (JOB_DIR / "tmp").mkdir(exist_ok=True)

    atoms = bulk("Si", "diamond", a=5.43, cubic=True)
    input_data = {
        "control": {
            "calculation": "scf",
            "prefix": "silicon",
            "pseudo_dir": "./",
            "outdir": "./tmp",
            "tprnfor": True,
        },
        "system": {"ecutwfc": 18.0},
        "electrons": {"mixing_beta": 0.7, "conv_thr": 1.0e-8},
    }
    pseudopotentials = {"Si": PSEUDO}

    write_pw_input(
        JOB_DIR / "si.ase.in",
        atoms,
        input_data=input_data,
        pseudopotentials=pseudopotentials,
        kpts=(4, 4, 4),
    )
    print(f"Input yazildi: {JOB_DIR / 'si.ase.in'}")

    calc = make_espresso_calc(
        atoms,
        directory=str(JOB_DIR),
        pseudo_dir=pseudo_dir,
        pseudopotentials=pseudopotentials,
        input_data=input_data,
        kpts=(4, 4, 4),
        mpi_np=int(os.environ.get("QE_MPI_NP", "1")),
        mpi_nk=int(os.environ.get("QE_MPI_NK", "1")),
    )
    atoms.calc = calc

    energy = atoms.get_potential_energy()
    print(f"SCF enerji: {energy:.6f} eV")
    print("Kuvvetler (eV/Ang):")
    print(atoms.get_forces())
    print(f"Cikti: {JOB_DIR / 'espresso.pwo'}")


if __name__ == "__main__":
    main()
