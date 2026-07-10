# Quantum ESPRESSO 7.5 — Yetenekler ve Modüller

Bu belge, projedeki Docker imajında kurulu **Quantum ESPRESSO 7.5** paketinin bilimsel ve teknik yeteneklerini özetler.

**Sürüm:** 7.5.0  
**Kurulum:** Docker container (`qe-qe:latest`)  
**Lisans:** GNU GPL v2 (açık kaynak)  
**Resmi site:** https://www.quantum-espresso.org/

---

## Genel bakış

Quantum ESPRESSO (QE), **yogunluk fonksiyonel teorisi (DFT)** tabanlı elektronik yapı hesapları için geliştirilmiş, modüler ve paralel bir yazılım paketidir. Kristaller, yüzeyler, nanoyapılar, moleküller ve katılar üzerinde:

- Elektronik yapı (enerji seviyeleri, bantlar, gappedir)
- Geometrik optimizasyon (iyon pozisyonları, hücre parametreleri)
- Titreşimsel özellikler (fononlar)
- Termodinamik ve mekanik özellikler
- Spektroskopi ve taşınım özellikleri
- Etkin potansiyel ve Wannier fonksiyonları

gibi hesaplamalar yapılabilir.

Bu kurulumda **MPI paralelleştirme**, **OpenMP** ve **ScaLAPACK** desteği etkindir; Linux HPC sistemlerinde de çalıştırılabilir.

---

## Temel fiziksel yöntemler

| Yöntem | Açıklama |
|--------|----------|
| **DFT (Kohn–Sham)** | Temel elektronik yapı hesabı |
| **Pseudopotansiyel** | Çekirdek elektronları etkili potansiyelle değiştirme |
| **PAW / USPP / NC** | Farklı pseudo türleri (ultrasoft, norm-conserving, PAW) |
| **LDA / GGA / meta-GGA** | Değişim-korelasyon fonksiyonelleri (PBE, PBEsol, SCAN vb.) |
| **Hibrit fonksiyoneller** | HSE, PBE0 (sınırlı destek) |
| **DFT+U** | Hubbard U düzeltmesi (korelasyonlu sistemler) |
| **van der Waals** | Grimme D3, MBD gibi dispersiyon düzeltmeleri |
| **Spin-orbit coupling** | Relativistik / manyetik sistemler |
| **DFPT** | Yoğunluk fonksiyonel pertürasyon teorisi (fononlar, dielektrik sabit) |

---

## Ana modüller ve yetenekleri

### 1. PWscf — `pw.x`

**Plane-Wave Self-Consistent Field** — paketin çekirdek modülü.

| Yetenek | Açıklama |
|---------|----------|
| SCF / NSCF | Kendi-tutarlı ve sabit potansiyel altında elektronik yapı |
| Geometri optimizasyonu | İyon ve hücre parametrelerinin gevşetilmesi (`relax`, `vc-relax`) |
| Bant yapısı | Elektronik bantların hesaplanması (NSCF + `bands.x`) |
| Durum yoğunluğu (DOS) | `dos.x`, `projwfc.x` ile |
| Manyetik sistemler | Spin polarize / non-collinear hesaplar |
| DFT+U | Hubbard düzeltmesi |
| Sabit potansiyel / elektrik alan | Yüzeyler, polarizasyon |
| OS-DFT | Occupation matrix DFT |
| Etkin potansiyel | `pp.x` ile sonrası analiz |

**İlgili programlar:** `pw.x`, `bands.x`, `dos.x`, `projwfc.x`, `ev.x`, `plan_avg.x`

---

### 2. CP — `cp.x`

**Car–Parrinello moleküler dinamik**

| Yetenek | Açıklama |
|---------|----------|
| Ab initio MD | Elektronik ve iyonik serbestlik dereceleri birlikte |
| Sabit sıcaklık / basınç | NVT, NPT ensemble'ları |
| Metaller | k-noktası örnekleme ile |
| Wannier fonksiyonları | CP içinde lokalizasyon |

**İlgili programlar:** `cp.x`, `manycp.x`

---

### 3. PHonon — `ph.x`

**Fononlar ve DFPT**

| Yetenek | Açıklama |
|---------|----------|
| Fonon dispersiyonu | k-bağımlı titreşim modları |
| Dielektrik sabit | ε(ω), ε(0) |
| Born etkin yükler | Polar kristaller |
| İkinci / üçüncü derece IFC | Anharmonik etkiler (sınırlı) |
| Elektron-fonon coupling | EPW ile birlikte |
| Raman / IR | Seçim kuralları (uygulamaya bağlı) |

**İlgili programlar:** `ph.x`, `phcg.x`, `q2r.x`, `matdyn.x`, `dynmat.x`, `lambda.x`, `alpha2f.x`, `fqha.x`

---

### 4. EPW — `epw.x` (kaynak mevcut, ayrı executable listede yok)

**Elektron-fonon coupling (Wannier tabanlı)**

| Yetenek | Açıklama |
|---------|----------|
| Süperiletkenlik | Eliashberg, McMillan λ |
| İletkenlik | Boltzmann taşınım |
| Wannier interpolasyonu | k-mesh üzerinde interpolasyon |

*Not: Tam EPW iş akışı `ph.x` + `pw.x` + Wannier90 zinciri gerektirir.*

---

### 5. PP — Post-Processing — `pp.x`

**Yoğunluk, potansiyel ve analiz araçları**

| Yetenek | Açıklama |
|---------|----------|
| Charge density | Elektron yoğunluğu çıktıları |
| Potential | Hartree, XC, local potansiyel |
| STM simülasyonu | Tersme görüntü |
| ELF | Elektron lokalizasyon fonksiyonu |
| Bant / DOS projeksiyonu | Atom, orbital bazlı |
| Wannier90 arayüzü | `pw2wannier90.x` |
| BGW / GW arayüzü | `pw2bgw.x`, `pw2gw.x` |
| XSF dönüşümü | XCrySDen, VESTA için `pwi2xsf.x` |

**İlgili programlar:** `pp.x`, `plotband.x`, `plotrho.x`, `projwfc.x`, `pw2wannier90.x`, `average.x`, `plan_avg.x`

---

### 6. NEB — `neb.x`

**Nudged Elastic Band — reaksiyon yolları**

| Yetenek | Açıklama |
|---------|----------|
| Geçiş hali (TS) arama | Minimum enerji yolu |
| Aktivasyon enerjisi | Bariyer yüksekliği |
| Çoklu image | Paralel image desteği |
| Climbing-image NEB | Gelişmiş bariyer arama |

**İlgili programlar:** `neb.x`

---

### 7. TDDFPT — Zaman-bağımlı DFT

**Optik ve eksitasyon spektrumları**

| Yetenek | Açıklama |
|---------|----------|
| Optik absorpsiyon | Dielektrik fonksiyon ε(ω) |
| Eksitasyon enerjileri | LR-TDDFT |
| TurboMagnon | Manyetik eksitasyonlar |
| TurboEELS | Elektron enerji kaybı spektroskopisi |
| Magnon spektrumları | `turbo_magnon.x` |

**İlgili programlar:** `turbo_lanczos.x`, `turbo_spectrum.x`, `turbo_eels.x`, `turbo_magnon.x`, `turbo_davidson.x`

---

### 8. HP — `hp.x`

**Hubbard parametreleri (DFT+U)**

| Yetenek | Açıklama |
|---------|----------|
| U, J hesabı | Malzeme-spesifik Hubbard parametreleri |
| DFT+U+J | Gelişmiş korelasyon düzeltmesi |

**İlgili programlar:** `hp.x`

---

### 9. KCW — `kcw.x`

**Koopmans-compliant Wannier (KCW)**

| Yetenek | Açıklama |
|---------|----------|
| Koopmans uyumlu spektrum | Quasiparticle enerjileri |
| Wannier tabanlı screening | Periyodik sistemlerde band gap düzeltmesi |

**İlgili programlar:** `kcw.x`, `kcwpp_interp.x`, `kcwpp_sh.x`

---

### 10. GWW — `gww.x`, `pw4gww.x`

**GW yaklaşımı (sınırlı kapsam)**

| Yetenek | Açıklama |
|---------|----------|
| Quasiparticle enerjiler | GW düzeltmesi |
| BSE | Bethe–Salpeter eksitasyonları |
| Spektral fonksiyonlar | `bse_main.x`, `simple_bse.x` |

**İlgili programlar:** `gww.x`, `pw4gww.x`, `head.x`, `bse_main.x`, `simple_bse.x`

---

### 11. PWCOND — `pwcond.x`

**İletkenlik ve balistik taşınım**

| Yetenek | Açıklama |
|---------|----------|
| İletim modları | Nanokontaklar, tünelleme |
| Landauer-Büttiker | İletkenlik hesabı |

**İlgili programlar:** `pwcond.x`

---

### 12. XSpectra — `xspectra.x`

**X-ışını absorpsiyon spektroskopisi (XAS)**

| Yetenek | Açıklama |
|---------|----------|
| K, L kenar spektrumları | Çekirdek seviye eksitasyonları |
| XANES / NEXAFS | Yakın kenar yapısı |

**İlgili programlar:** `xspectra.x`, `molecularnexafs.x`, `initial_state.x`

---

### 13. QEHeat — `postahc.x`

**Anharmonik taşınım özellikleri**

| Yetenek | Açıklama |
|---------|----------|
| Isı iletkenliği | Phonon–phonon scattering |
| Anharmonik lattice dynamics | Sınırlı malzemeler |

**İlgili programlar:** `postahc.x`

---

### 14. PIOUD — `pioud.x`

**Path-integral molecular dynamics (sınırlı)**

| Yetenek | Açıklama |
|---------|----------|
| Kuantum nükleer efektler | Path integral MD |

**İlgili programlar:** `pioud.x`

---

### 15. Atomic — `ld1.x`

**Pseudopotansiyel üretimi**

| Yetenek | Açıklama |
|---------|----------|
| Atomik DFT | Tek atom hesabı |
| UPF üretimi | Özel pseudopotansiyel oluşturma |
| Test ve doğrulama | Pseudo kalite kontrolü |

**İlgili programlar:** `ld1.x`

---

### 16. Wannier90 — `wannier90.x`

**Maksimally localized Wannier fonksiyonları**

| Yetenek | Açıklama |
|---------|----------|
| Wannier interpolasyonu | Bant yapısı, Fermi yüzeyi |
| Berry phase | Polarizasyon, orbital magnetizasyon |
| EPW / KCW ön hazırlık | Elektron-fonon, KCW iş akışları |

**İlgili programlar:** `wannier90.x`, `pw2wannier90.x`, `wannier2pw.x`, `postw90.x`, `wannier_ham.x`, `wannier_plot.x`

---

## Yardımcı ve dönüşüm araçları

| Program | İşlev |
|---------|-------|
| `ibrav2cell.x` / `cell2ibrav.x` | Bravais lattice dönüşümleri |
| `kpoints.x` | k-noktası üretimi |
| `dist.x` | Mesafe hesabı |
| `pwi2xsf.x` | XCrySDen / VESTA formatı |
| `pw2critic.x` | Critic2 arayüzü |
| `open_grid.x` | k-grid açma |
| `path_interpolation.x` | Yüksek simetri yolları |
| `scan_ibrav.x` | Lattice tarama |
| `sumpdos.x` | PDOS toplama |
| `fermi_velocity.x` | Fermi hızı |
| `d3hess.x` | Üçüncü derece Hessian |

---

## Paralelleştirme yetenekleri (bu kurulum)

| Özellik | Durum |
|---------|-------|
| **MPI** | Etkin — node/process arası (`mpirun -np N`) |
| **OpenMP** | Etkin — çekirdek içi (`OMP_NUM_THREADS`) |
| **k-point pools** | `-nk` bayrağı |
| **Band parallelization** | `-nb` bayrağı |
| **Task groups** | `-nt` bayrağı |
| **Linear algebra parallel** | ScaLAPACK (`-nd`) |
| **Hibrit MPI+OpenMP** | Desteklenir |

---

## Tipik hesaplama iş akışları

### Kristal elektronik yapı
```
pw.x (SCF) → pw.x (NSCF) → bands.x → plotband.x
```

### Fononlar
```
pw.x (SCF) → ph.x → q2r.x → matdyn.x
```

### Reaksiyon bariyeri
```
pw.x (relax başlangıç/son) → neb.x
```

### Optik spektrum
```
pw.x (SCF) → turbo_lanczos.x → turbo_spectrum.x
```

### Wannier + EPW
```
pw.x → pw.x (NSCF) → pw2wannier90.x → wannier90.x → (epw iş akışı)
```

### DFT+U parametreleri
```
pw.x (SCF) → hp.x
```

---

## Desteklenen malzeme sınıfları

- Yarıiletkenler ve metaller (Si, GaAs, Fe, Cu vb.)
- İzolatörler ve geniş bantlı malzemeler
- 2D malzemeler (grafen, TMD'ler — uygun vacuum/slab modeli ile)
- Yüzeyler ve arayüzler (slab + dipol düzeltmesi)
- Nanoparçacıklar ve kümeler (süper hücre)
- Moleküler kristaller
- Manyetik ve spin-orbit sistemler
- Korelasyonlu sistemler (DFT+U, HP)

---

## Sınırlamalar

| Konu | Not |
|------|-----|
| **GPU** | Bu Docker imajında CUDA/OpenACC yok |
| **Windows native** | Doğrudan Windows kurulumu yok; yalnızca container |
| **GUI** | Grafik arayüz yok; input/output dosya tabanlı |
| **Tüm XC fonksiyonelleri** | Libxc olmadan derlendi; bazı meta-GGA/hibrit sınırlı |
| **Çok büyük sistemler** | Bellek ve CPU sayısına bağlı; HPC önerilir |
| **Kuantum kimya hassasiyeti** | CCSD(T) vb. yarı-empirik yöntemler yok; ab initio DFT |

---

## Kurulu çalıştırılabilir dosyalar (özet)

Container içinde **80+** `.x` programı mevcuttur. Tam liste:

```powershell
docker compose run --rm qe bash -lc "ls /opt/qe-7.5/bin/*.x | xargs -n1 basename | sort"
```

Ana programlar: `pw.x`, `ph.x`, `pp.x`, `cp.x`, `neb.x`, `bands.x`, `dos.x`, `hp.x`, `kcw.x`, `gww.x`, `pwcond.x`, `xspectra.x`, `wannier90.x`, `ld1.x`, `turbo_*`, `postahc.x`, `pioud.x`

---

## Ek dokümantasyon

| Dosya | Konu |
|-------|------|
| `manuels/user_guide.pdf` | Genel kurulum ve kullanım |
| `manuels/pw_user_guide.pdf` | PWscf detayları |
| `manuels/ph_user_guide.pdf` | Fononlar |
| `manuels/pp_user_guide.pdf` | Post-processing |
| `manuels/neb_user_guide.pdf` | NEB |
| `manuels/Hubbard_input.pdf` | DFT+U |
| `manuels/pseudo-gen.pdf` | Pseudopotansiyel üretimi |
| `KULLANIM.md` | Bu projede Docker kullanımı |

---

## Özet

Quantum ESPRESSO 7.5, **katı hâl fizik ve malzeme bilimi** araştırmaları için kapsamlı bir DFT platformudur. Bu Docker kurulumu; elektronik yapı, geometri optimizasyonu, fononlar, spektroskopi, taşınım, reaksiyon yolları ve gelişmiş korelasyon düzeltmelerini **MPI paralel** ortamda çalıştırmaya hazırdır.
