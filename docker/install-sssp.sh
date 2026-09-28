#!/bin/bash
# Install SSSP PBE efficiency pseudopotentials and set ESPRESSO_PSEUDO.
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
PSEUDO_DIR="${ESPRESSO_PSEUDO:-${QE_ROOT}/pseudo}"
SSSP_VER="${SSSP_VER:-1.3.0}"
SSSP_FILE="SSSP_${SSSP_VER}_PBE_efficiency.tar.gz"
SSSP_URL="https://archive.materialscloud.org/records/rcyfm-68h65/files/${SSSP_FILE}"
SSSP_MD5="${SSSP_MD5:-a58f1b3373f330179fd0832c48bb9a52}"

mkdir -p "${PSEUDO_DIR}"
cd /tmp
echo "=== Downloading SSSP ${SSSP_VER} PBE efficiency ==="
wget -q --content-disposition -O "${SSSP_FILE}" "${SSSP_URL}" \
  || curl -fsSL -L -o "${SSSP_FILE}" "${SSSP_URL}"

if command -v md5sum >/dev/null 2>&1; then
  echo "${SSSP_MD5}  ${SSSP_FILE}" | md5sum -c -
elif command -v md5 >/dev/null 2>&1; then
  got="$(md5 -q "${SSSP_FILE}")"
  [ "${got}" = "${SSSP_MD5}" ] || { echo "MD5 mismatch: ${got}"; exit 1; }
fi

tar -xzf "${SSSP_FILE}" -C "${PSEUDO_DIR}"
# Flatten if archive has a single top-level directory of UPF files
if [ "$(find "${PSEUDO_DIR}" -maxdepth 1 -name '*.UPF' | wc -l)" -eq 0 ]; then
  find "${PSEUDO_DIR}" -type f -name '*.UPF' -exec mv -n {} "${PSEUDO_DIR}/" \;
fi

# Keep a classic LDA Si for tiny smoke tests if present in QE tree
if [ -f "${QE_ROOT}/atomic/examples/pseudo-LDA-0.5/Si.pz-vbc.UPF" ]; then
  cp -n "${QE_ROOT}/atomic/examples/pseudo-LDA-0.5/Si.pz-vbc.UPF" "${PSEUDO_DIR}/" || true
fi

n_upf="$(find "${PSEUDO_DIR}" -maxdepth 1 -name '*.UPF' | wc -l | tr -d ' ')"
echo "=== SSSP installed: ${n_upf} UPF files in ${PSEUDO_DIR} ==="
[ "${n_upf}" -ge 50 ]

rm -f "/tmp/${SSSP_FILE}"
