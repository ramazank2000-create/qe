FROM ubuntu:22.04

# Standalone Quantum ESPRESSO 7.6 image (docker-compose). Portal image: ../dockerfiles/qe.
ENV DEBIAN_FRONTEND=noninteractive
ENV QE_ROOT=/opt/qe-7.6
ENV OPENMPI_PREFIX=/usr/local/openmpi-4.1.8
ENV ELPA_PREFIX=/usr/local/elpa-2024.05.001
ENV LC_ALL=C
ENV LANG=C.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries && \
    apt-get install -y --no-install-recommends \
        bc build-essential cmake curl g++ gcc gfortran git \
        libfftw3-dev libfftw3-mpi-dev \
        liblapack-dev libopenblas-dev libscalapack-openmpi-dev \
        libhdf5-dev libhdf5-openmpi-dev hdf5-tools libxc-dev \
        libpmix-dev libevent-dev libhwloc-dev zlib1g-dev \
        libslurm-dev libpmi2-0-dev \
        m4 make openmpi-bin python3 python3-dev python3-numpy python3-pip python3-venv \
        wget time \
    && rm -rf /var/lib/apt/lists/*

COPY docker/install-openmpi.sh /docker/install-openmpi.sh
RUN sed -i 's/\r$//' /docker/install-openmpi.sh && bash /docker/install-openmpi.sh

ENV PATH=${OPENMPI_PREFIX}/bin:${PATH} \
    LD_LIBRARY_PATH=${OPENMPI_PREFIX}/lib \
    OMP_NUM_THREADS=1 \
    OMPI_MCA_btl_vader_single_copy_mechanism=none \
    OMPI_MCA_hwloc_base_binding_policy=none

COPY docker/install-elpa.sh /docker/install-elpa.sh
RUN sed -i 's/\r$//' /docker/install-elpa.sh && bash /docker/install-elpa.sh
ENV LD_LIBRARY_PATH=${ELPA_PREFIX}/lib:${LD_LIBRARY_PATH}

# Place q-e-qe-7.6.tar.gz (or qe-7.6-ReleasePack.tar.gz) in softwares/ before build.
COPY softwares/q-e-qe-7.6.tar.gz /tmp/q-e-qe-7.6.tar.gz
RUN tar -xzf /tmp/q-e-qe-7.6.tar.gz -C /opt && \
    mv /opt/q-e-qe-7.6 ${QE_ROOT} && \
    rm -f /tmp/q-e-qe-7.6.tar.gz

COPY docker/ /docker/
RUN sed -i 's/\r$//' /docker/*.sh && chmod +x /docker/*.sh

RUN /docker/install-qe.sh
RUN /docker/install-sssp.sh || true
RUN /docker/run-tests.sh

COPY requirements.txt /tmp/requirements.txt
COPY python/ /opt/qe-python/
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt BoltzTraP2==26.3.1 && \
    pip3 install --no-cache-dir /opt/qe-python/ && \
    python3 -c "import ase; import qe_ase; import BoltzTraP2; print('ASE', ase.__version__, 'qe_ase', qe_ase.__version__)"

RUN /docker/test-ase.sh

RUN useradd -m -u 1000 -s /bin/bash qe && \
    /docker/setup-qe-user.sh && \
    chown -R qe:qe /docker "${QE_ROOT}/tempdir" "${QE_ROOT}/pseudo"

USER qe
WORKDIR /home/qe

ENV HOME=/home/qe
ENV PATH=${QE_ROOT}/bin:${OPENMPI_PREFIX}/bin:${PATH}
ENV ESPRESSO_PSEUDO=${QE_ROOT}/pseudo
ENV OMP_NUM_THREADS=1

ENTRYPOINT ["/docker/entrypoint.sh"]
