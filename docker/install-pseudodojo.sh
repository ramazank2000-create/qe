#!/bin/bash
# PseudoDojo v0.4 PBE "standard" norm-conserving UPF tables, complete element sets, scalar-relativistic (SR) and
# fully relativistic (FR, has_so=T: noncolin + lspinorb) → ${QE_ROOT}/pseudo-dojo/nc-{sr,fr}-04_pbe_standard/ + SOURCES.md.
# In the image because HPC compute nodes may have no internet. Archive URLs as in quantum/tools/perov.py (DOJO);
# cutoff hints from standard.djson at a pinned commit. Archives and djson are md5-pinned.
set -euo pipefail

QE_ROOT="${QE_ROOT:-/opt/qe-7.6}"
DEST="${PSEUDO_DOJO_DIR:-${QE_ROOT}/pseudo-dojo}"
# kind  has_so  archive-md5  hints-repo  hints-commit  hints-md5
SETS=(
  "sr F 68c9e10f8433b615fcef6fb183a5c2bb ONCVPSP-PBE-PDv0.4    134d757178552b8228a43a848b0e53f232cdda84 e0c0da895b566e78b71a79105ccba8b2"
  "fr T 9c3f1fe164e3d014dcf1b99964fa7296 ONCVPSP-PBE-FR-PDv0.4 7ade53476f31cd38e37246f1b9f0ad38adb0edc3 fd1fb4d1ac31209c0d76dc6ec6ed98d2"
)

for row in "${SETS[@]}"; do
  read -r kind so amd5 repo sha hmd5 <<<"${row}"
  name="nc-${kind}-04_pbe_standard"
  out="${DEST}/${name}"
  tgz_url="https://www.pseudo-dojo.org/pseudos/${name}_upf.tgz"
  hints_url="https://raw.githubusercontent.com/PseudoDojo/${repo}/${sha}/standard.djson"
  w="$(mktemp -d)"
  echo "=== ${name}: ${tgz_url} ==="
  curl -fsSL --retry 3 -o "${w}/a.tgz" "${tgz_url}"
  curl -fsSL --retry 3 -o "${w}/standard.djson" "${hints_url}"
  echo "${amd5}  ${w}/a.tgz" | md5sum -c -
  echo "${hmd5}  ${w}/standard.djson" | md5sum -c -
  mkdir -p "${w}/x" "${out}"
  tar --no-same-owner -xzf "${w}/a.tgz" -C "${w}/x"
  find "${w}/x" -type f -name '*.upf' -exec mv -n {} "${out}/" \;

  python3 - "${out}" "${so}" "${w}/standard.djson" "${tgz_url}" "${amd5}" "${hints_url}" "${hmd5}" "${repo}" <<'PY'
import datetime, hashlib, json, re, sys
from pathlib import Path

out, so, djson, tgz_url, amd5, hints_url, hmd5, repo = sys.argv[1:]
want_so = so == "T"
meta = json.loads(Path(djson).read_text())["pseudos_metadata"]
rows = []
for f in sorted(Path(out).glob("*.upf")):
    raw = f.read_bytes()
    m = re.search(rb"<PP_HEADER\b([^>]*)>", raw)
    assert m, f"{f.name}: no PP_HEADER"
    at = {k.decode().lower(): v.decode().strip() for k, v in re.findall(rb'(\w+)\s*=\s*"([^"]*)"', m.group(1))}
    has_so = at.get("has_so", "F").upper().strip(".") in ("T", "TRUE")
    assert at.get("pseudo_type", "").upper() == "NC" and b"<PP_AUGMENTATION" not in raw, f"{f.name}: not NC"
    assert has_so == want_so, f"{f.name}: has_so={has_so}, set expects {want_so}"
    el = f.stem
    h = meta.get(el, {}).get("hints", {})
    ha = [h[k]["ecut"] for k in ("low", "normal", "high") if k in h]
    rows.append((el, f.name, hashlib.md5(raw).hexdigest(), float(at["z_valence"]), meta.get(el, {}).get("basename", "?"), ha))
missing = sorted(set(meta) - {r[0] for r in rows})
rel = "fully relativistic (has_so=T; for noncolin=.true. + lspinorb=.true.)" if want_so else "scalar-relativistic"
fmt = lambda xs: " / ".join(f"{x:g}" for x in xs) or "-"   # noqa: E731
md = [f"# PseudoDojo v0.4 PBE standard, norm-conserving, {rel}", "",
      f"Installed {datetime.date.today().isoformat()} into 127.0.0.1:5000/qc/qe:7.6 by quantum/qe/docker/install-pseudodojo.sh.", "",
      f"- Archive: {tgz_url} (md5 {amd5})",
      f"- Cutoff hints: {hints_url} (md5 {hmd5}; repository https://github.com/PseudoDojo/{repo}); "
      "`hints` low / normal / high are ecutwfc in Ha (Ry = 2 x Ha)",
      "- Table: PseudoDojo v0.4, PBE, standard accuracy, ONCVPSP norm-conserving (pseudo_type NC)",
      "- License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/); credit the PseudoDojo project.",
      "- Cite: M. J. van Setten et al., Comput. Phys. Commun. 226, 39 (2018); "
      "D. R. Hamann, Phys. Rev. B 88, 085117 (2013).",
      f"- Files: {len(rows)} UPF" + (f"; in standard.djson but not in the archive: {', '.join(missing)}" if missing else ""),
      f"- Use: pseudo_dir = '{out}' (or `perov.py qe <cif> --pseudo-dir {out} --dual 4`); NC: ecutrho = 4 x ecutwfc. "
      "Converge ecutwfc anyway (`perov.py qe ... --task conv`).", "",
      "| element | file | md5 | Z_val | djson basename | hint low / normal / high (Ha) | (Ry) |",
      "|---|---|---|---|---|---|---|"]
md += [f"| {el} | {fn} | {h} | {z:g} | {b} | {fmt(ha)} | {fmt([2 * x for x in ha])} |" for el, fn, h, z, b, ha in rows]
Path(out, "SOURCES.md").write_text("\n".join(md) + "\n")
print(f"{out}: {len(rows)} UPF (has_so={want_so}), SOURCES.md written; djson elements without UPF: {missing or 'none'}")
assert len(rows) >= 60, "archive looks incomplete"
PY
  rm -rf "${w}"
done

chmod -R a+rX "${DEST}"
echo "=== PseudoDojo installed under ${DEST} ==="
