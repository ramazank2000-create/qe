"""Quantum ESPRESSO calculator helpers built on ASE."""

from __future__ import annotations

import os
from pathlib import Path
from typing import Any

from ase import Atoms
from ase.calculators.espresso import Espresso, EspressoProfile


def qe_root() -> Path:
    return Path(os.environ.get("QE_ROOT", "/opt/qe-7.5"))


def default_pseudo_dir() -> Path:
    return Path(os.environ.get("ESPRESSO_PSEUDO", qe_root() / "pseudo"))


def mpi_command(
    np: int = 1,
    nk: int = 1,
    exe: str | None = None,
) -> str:
    """Build an mpirun command string for pw.x."""
    pw = exe or str(qe_root() / "bin" / "pw.x")
    parts = ["mpirun", "-np", str(np), pw]
    if nk > 0:
        parts.extend(["-nk", str(nk)])
    return " ".join(parts)


def make_profile(
    *,
    pseudo_dir: str | Path | None = None,
    mpi_np: int | None = None,
    mpi_nk: int | None = None,
    command: str | None = None,
) -> EspressoProfile:
    """Create an EspressoProfile with Docker/QE defaults."""
    np = mpi_np if mpi_np is not None else int(os.environ.get("QE_MPI_NP", "1"))
    nk = mpi_nk if mpi_nk is not None else int(os.environ.get("QE_MPI_NK", "1"))
    return EspressoProfile(
        command=command or mpi_command(np=np, nk=nk),
        pseudo_dir=str(pseudo_dir or default_pseudo_dir()),
    )


def make_espresso_calc(
    atoms: Atoms,
    *,
    pseudopotentials: dict[str, str],
    pseudo_dir: str | Path | None = None,
    input_data: dict[str, Any] | None = None,
    profile: EspressoProfile | None = None,
    mpi_np: int | None = None,
    mpi_nk: int | None = None,
    command: str | None = None,
    directory: str | Path = ".",
    kpts: tuple[int, int, int] | None = None,
    kspacing: float | None = None,
    **kwargs: Any,
) -> Espresso:
    """Return a configured ASE Espresso calculator for pw.x."""
    calc_profile = profile or make_profile(
        pseudo_dir=pseudo_dir,
        mpi_np=mpi_np,
        mpi_nk=mpi_nk,
        command=command,
    )

    calc_kwargs: dict[str, Any] = {
        "profile": calc_profile,
        "pseudopotentials": pseudopotentials,
        "directory": str(directory),
        "input_data": input_data or {},
    }
    if kpts is not None:
        calc_kwargs["kpts"] = kpts
    if kspacing is not None:
        calc_kwargs["kspacing"] = kspacing
    calc_kwargs.update(kwargs)
    return Espresso(**calc_kwargs)
