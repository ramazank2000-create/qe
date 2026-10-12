#!/bin/bash
# phonopy into /opt/venv (same 4.7.x as the CP2K image). pip may only ADD packages: every version already in the
# venv (numpy, scipy, spglib, ASE, BoltzTraP2 deps) is pinned as a constraint, so nothing installed earlier changes.
set -euo pipefail

PHONOPY_VERSION="${PHONOPY_VERSION:-4.7.2}"
PIP=/opt/venv/bin/pip
PINS="$(mktemp)"

"${PIP}" freeze | grep '==' > "${PINS}"
"${PIP}" install --no-cache-dir -c "${PINS}" "phonopy==${PHONOPY_VERSION}"
rm -f "${PINS}"

/opt/venv/bin/python -c "import phonopy, numpy, spglib; print('phonopy', phonopy.__version__, 'numpy', numpy.__version__, 'spglib', spglib.__version__)"
/opt/venv/bin/phonopy --help > /dev/null   # 4.x has no --version; the banner of a run shows it
echo "=== phonopy ${PHONOPY_VERSION} installed in /opt/venv ==="
