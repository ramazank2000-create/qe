# Quantum ESPRESSO 7.5 Docker Kullanım Kılavuzu

Bu kılavuz, QE 7.5 Docker imajının kullanımını ve Windows terminalinden job çalıştırmayı açıklar.

## Önemli: `qe.exe` yoktur

PowerShell'de `qe.exe` yazdığınızda hata alırsınız — bu normaldir. Quantum ESPRESSO Windows'a doğrudan kurulmamıştır; **Linux container içinde** çalışır (`pw.x`, `ph.x`, `bands.x` vb.).

Komutları şu yollarla çalıştırırsınız:

1. `docker compose run --rm qe bash -lc "..."` — tek seferlik job
2. `docker compose exec qe bash` — çalışan container'a bağlanma

---

## Gereksinimler

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows)
- Docker Compose v2
- Kaynak arşivi: `softwares/qe-7.5-ReleasePack.tar.gz`

## Proje yapısı

```
qe/
├── Dockerfile
├── docker-compose.yml
├── docker/                  # kurulum ve test scriptleri
├── jobs_qe/                 # Host ↔ container paylaşımlı hesap klasörü
│   ├── deneme/              # örnek Si SCF hesabı (manuel input)
│   └── ase_deneme/          # örnek Si SCF (ASE/Python)
│       └── si_scf.py
├── python/                  # qe_ase yardımcı modülü (imaja kurulur)
│   └── qe_ase/
├── requirements.txt         # Python bağımlılıkları (ASE)
├── softwares/
│   └── qe-7.5-ReleasePack.tar.gz
└── manuels/                 # resmi PDF kılavuzlar
```

**Volume eşlemesi:** `c:\projects\qe\jobs_qe` → container içinde `/home/qe/jobs_qe`

Host'ta oluşturduğunuz dosyalar container'da görünür; çıktılar da host'ta kalır.

---

## 1. İmajı oluşturma (ilk kurulum)

Proje kök dizininde (`c:\projects\qe`):

```powershell
cd c:\projects\qe
docker compose build
```

İlk derleme **uzun sürer** (yaklaşık 30–90 dakika). Tamamlandığında imaj adı: `qe-qe:latest`.

### Derleme doğrulama

```powershell
docker compose run --rm qe bash -lc "pw.x -v 2>&1 | head -3"
```

---

## 2. Container'ı başlatma

```powershell
docker compose up -d
```

### Durum kontrolü

```powershell
docker compose ps
docker compose logs qe
```

### Durdurma

```powershell
docker compose stop
docker compose start
```

---

## 3. Terminalden job çalıştırma

Tüm örnekler **PowerShell** içindir; proje kökünden (`c:\projects\qe`) çalıştırın.

### 3.1 Tek process (seri / 1 MPI rank)

```powershell
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/deneme && mkdir -p tmp && mpirun -np 1 pw.x -nk 1 < si.scf.in > si.scf.out"
```

Çıktıyı host'ta kontrol:

```powershell
Select-String -Path jobs_qe\deneme\si.scf.out -Pattern "convergence has been achieved"
```

### 3.2 Paralel (2 MPI process)

```powershell
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/deneme && mkdir -p tmp && mpirun -np 2 pw.x -nk 1 < si.scf.in > si.mpi.out"
```

Process sayısını değiştirmek için `-np 2` kısmını güncelleyin (ör. `-np 4`).

### 3.3 Container içine girerek çalışma (interaktif)

```powershell
docker compose exec qe bash
```

Container içinde:

```bash
cd ~/jobs_qe/deneme
mkdir -p tmp
mpirun -np 2 pw.x -nk 1 < si.scf.in > si.mpi.out
grep "convergence" si.mpi.out
exit
```

### 3.4 Yeni job klasörü oluşturma

Host'ta yeni klasör açın:

```
jobs_qe\
  benim_hesabim\
    sistem.scf.in
    Si.pz-vbc.UPF    # veya başka pseudo
    tmp\             # outdir (isteğe bağlı, job öncesi mkdir)
```

Çalıştırma:

```powershell
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/benim_hesabim && mkdir -p tmp && mpirun -np 4 pw.x -nk 2 < sistem.scf.in > sistem.scf.out"
```

---

## 3.5 ASE / Python ile hesaplama

Container içinde **ASE (Atomic Simulation Environment)** ve `qe_ase` yardımcı modülü kuruludur. Yapı oluşturma, input yazma ve `pw.x` çalıştırma Python üzerinden yapılabilir.

### Örnek: silisyum SCF (ASE)

```powershell
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/ase_deneme && python3 si_scf.py"
```

2 MPI process ile:

```powershell
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/ase_deneme && QE_MPI_NP=2 QE_MPI_NK=1 python3 si_scf.py"
```

Script şunları yapar:

1. ASE ile elmas yapılı Si hücresi oluşturur
2. `si.ase.in` input dosyasını yazar
3. `pw.x` ile SCF hesabını çalıştırır
4. Enerji ve kuvvetleri ekrana basar

Çıktılar host'ta `jobs_qe\ase_deneme\` altında kalır (`espresso.pwo`, `si.ase.in`, `tmp/`).

### Kendi Python scriptiniz

Container içinde veya `jobs_qe` altına `.py` dosyası koyarak kullanabilirsiniz:

```python
from ase.build import bulk
from qe_ase import make_espresso_calc, write_pw_input

atoms = bulk("Si", "diamond", a=5.43, cubic=True)
pseudopotentials = {"Si": "Si.pz-vbc.UPF"}

input_data = {
    "control": {"calculation": "scf", "outdir": "./tmp"},
    "system": {"ecutwfc": 30.0},
    "electrons": {"conv_thr": 1e-8},
}

write_pw_input("si.in", atoms, input_data=input_data, pseudopotentials=pseudopotentials, kpts=(4, 4, 4))

calc = make_espresso_calc(
    atoms,
    pseudo_dir="/opt/qe-7.5/pseudo",
    pseudopotentials=pseudopotentials,
    input_data=input_data,
    kpts=(4, 4, 4),
    mpi_np=2,
    mpi_nk=1,
)
atoms.calc = calc
print(atoms.get_potential_energy())
```

### `qe_ase` modülü

| Fonksiyon | Açıklama |
|-----------|----------|
| `make_espresso_calc()` | ASE `Espresso` hesaplayıcısı (MPI, pseudo_dir varsayılanları ile) |
| `make_profile()` | `EspressoProfile` oluşturur |
| `mpi_command()` | `mpirun -np N pw.x -nk K` komut dizisi |
| `write_pw_input()` | Yalnızca input dosyası yazar (hesap çalıştırmaz) |
| `read_pw_output()` | `pw.x` çıktısından yapı okur |

Ortam değişkenleri:

| Değişken | Varsayılan | Anlamı |
|----------|------------|--------|
| `QE_MPI_NP` | `1` | MPI process sayısı |
| `QE_MPI_NK` | `1` | k-point pool sayısı |
| `QE_ROOT` | `/opt/qe-7.5` | QE kurulum dizini |
| `ESPRESSO_PSEUDO` | `$QE_ROOT/pseudo` | Pseudopotansiyel dizini |

### ASE ile geometri optimizasyonu

```python
from ase.build import bulk
from ase.optimize import LBFGS
from qe_ase import make_espresso_calc

atoms = bulk("Si", "diamond", a=5.43)
atoms.calc = make_espresso_calc(
    atoms,
    pseudo_dir="/opt/qe-7.5/pseudo",
    pseudopotentials={"Si": "Si.pz-vbc.UPF"},
    input_data={"system": {"ecutwfc": 30.0}},
    kpts=(4, 4, 4),
)
LBFGS(atoms).run(fmax=0.05)
```

---

## 4. Sık kullanılan programlar

| Program | Açıklama | Örnek |
|---------|----------|-------|
| `pw.x` | SCF, relax, bands | `mpirun -np N pw.x -nk K < input.in > output.out` |
| `ph.x` | Fononlar | SCF sonrası `ph.x` input |
| `pp.x` | Post-processing | Charge density, potential |
| `bands.x` | Bant yapısı | NSCF sonrası |
| `neb.x` | NEB geçiş yolu | Çoklu image |
| `cp.x` | Car-Parrinello MD | `cp.x` input |

Tüm çalıştırılabilir dosyalar: `/opt/qe-7.5/bin/`

Listelemek için:

```powershell
docker compose run --rm qe bash -lc "ls /opt/qe-7.5/bin/*.x | head -20"
```

---

## 5. Input dosyası ipuçları

Örnek `si.scf.in` içinde:

- `pseudo_dir = './'` — pseudopotansiyel aynı klasörde
- `outdir='./tmp'` — geçici dosyalar `tmp/` altında
- `prefix='silicon'` — çıktı dosya öneki

Pseudopotansiyelleri container'daki hazır kütüphaneden de alabilirsiniz:

```text
pseudo_dir = '/opt/qe-7.5/pseudo/'
```

Host'taki `jobs_qe` klasörüne `.UPF` dosyasını kopyalamak genelde daha pratiktir.

---

## 6. Paralelleştirme (MPI + OpenMP)

### MPI (process arası)

```text
mpirun -np N pw.x -nk K < input.in > output.out
```

| Bayrak | Anlamı |
|--------|--------|
| `-np N` | MPI process sayısı |
| `-nk K` | k-point pool sayısı (N ile uyumlu olmalı) |

Örnek: 4 process, 2 pool → `mpirun -np 4 pw.x -nk 2`

### OpenMP (çekirdek içi)

`docker-compose.yml` içinde `OMP_NUM_THREADS: 4`. Değiştirmek için:

```yaml
environment:
  OMP_NUM_THREADS: 8
```

Hibrit kullanım: `N_MPI × OMP_NUM_THREADS` ≈ toplam çekirdek.

---

## 7. HPC (Linux küme) kullanımı

İmajı dışa aktarma (Windows):

```powershell
docker save qe-qe:latest -o qe-7.5.tar
```

Kümede (Singularity/Apptainer):

```bash
singularity build qe-7.5.sif docker-archive://qe-7.5.tar

srun singularity exec --bind /path/to/jobs_qe:/home/qe/jobs_qe \
  qe-7.5.sif mpirun -np 16 pw.x -nk 4 < si.scf.in > si.scf.out
```

---

## 8. Sorun giderme

### `qe.exe` tanınmıyor

QE Windows'ta yüklü değil. `docker compose run --rm qe bash -lc "..."` kullanın.

### MPI / paylaşımlı bellek hatası

`docker-compose.yml` içinde `shm_size: "2gb"` tanımlıdır. Hata devam ederse değeri artırın.

### Pseudopotansiyel bulunamadı

Input'ta `pseudo_dir` doğru mu kontrol edin; `.UPF` dosyası o klasörde olmalı.

### Container çalışmıyor

```powershell
docker compose ps
docker compose up -d
docker compose logs qe
```

### Job çıktısı boş veya hata

```powershell
Get-Content jobs_qe\deneme\si.scf.out -Tail 40
```

`JOB DONE` veya `convergence has been achieved` satırlarını arayın.

---

## 9. Hızlı referans (kopyala-yapıştır)

```powershell
# Proje dizinine git
cd c:\projects\qe

# Container başlat
docker compose up -d

# Örnek SCF (2 MPI)
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/deneme && mkdir -p tmp && mpirun -np 2 pw.x -nk 1 < si.scf.in > si.mpi.out"

# Sonucu kontrol et
Select-String jobs_qe\deneme\si.mpi.out -Pattern "convergence"

# ASE ile Si SCF
docker compose run --rm qe bash -lc "cd /home/qe/jobs_qe/ase_deneme && python3 si_scf.py"
```

---

## 10. Ek dokümantasyon

- `manuels/user_guide.pdf` — kurulum ve genel kullanım
- `manuels/pw_user_guide.pdf` — PWscf (pw.x)
- `manuels/ph_user_guide.pdf` — fononlar (ph.x)
- `manuels/pp_user_guide.pdf` — post-processing (pp.x)

Resmi site: https://www.quantum-espresso.org/
