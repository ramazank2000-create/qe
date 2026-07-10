"""Input/output helpers for pw.x via ASE."""

from __future__ import annotations

from pathlib import Path
from typing import Any

from ase import Atoms
from ase.io.espresso import read_espresso_out, write_espresso_in


def write_pw_input(
    path: str | Path,
    atoms: Atoms,
    *,
    input_data: dict[str, Any] | None = None,
    pseudopotentials: dict[str, str] | None = None,
    kpts: tuple[int, int, int] | None = None,
    kspacing: float | None = None,
    **kwargs: Any,
) -> None:
    """Write a pw.x input file without running the calculation."""
    write_kwargs: dict[str, Any] = {}
    if input_data is not None:
        write_kwargs["input_data"] = input_data
    if pseudopotentials is not None:
        write_kwargs["pseudopotentials"] = pseudopotentials
    if kpts is not None:
        write_kwargs["kpts"] = kpts
    if kspacing is not None:
        write_kwargs["kspacing"] = kspacing
    write_kwargs.update(kwargs)
    write_espresso_in(path, atoms, **write_kwargs)


def read_pw_output(path: str | Path) -> list[Atoms]:
    """Read one or more structures from a pw.x output file."""
    return read_espresso_out(path)
