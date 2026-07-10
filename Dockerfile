FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV QE_ROOT=/opt/qe-7.5
ENV LC_ALL=C
ENV LANG=en_US.UTF-8

RUN apt-get update && \
    apt-get install -y --no-install-recommends ca-certificates && \
    echo 'Acquire::Retries "5";' > /etc/apt/apt.conf.d/80-retries && \
    (apt-get install -y --no-install-recommends \
        bc \
        build-essential \
        cmake \
        curl \
        g++ \
        gcc \
        gfortran \
        git \
        libfftw3-dev \
        liblapack-dev \
        libopenblas-dev \
        libopenmpi-dev \
        libscalapack-mpi-dev \
        m4 \
        make \
        openmpi-bin \
        python3 \
        python3-numpy \
        python3-pip \
        wget \
    || (apt-get update && apt-get install -y --fix-missing --no-install-recommends \
        bc build-essential cmake curl g++ gcc gfortran git \
        libfftw3-dev liblapack-dev libopenblas-dev libopenmpi-dev \
        libscalapack-mpi-dev m4 make openmpi-bin python3 python3-numpy python3-pip wget)) && \
    rm -rf /var/lib/apt/lists/*

WORKDIR ${QE_ROOT}

COPY softwares/qe-7.5-ReleasePack.tar.gz /tmp/qe-7.5-ReleasePack.tar.gz
RUN tar -xzf /tmp/qe-7.5-ReleasePack.tar.gz -C /opt && \
    rm -f /tmp/qe-7.5-ReleasePack.tar.gz

COPY docker/ /docker/
RUN sed -i 's/\r$//' /docker/*.sh && chmod +x /docker/*.sh

RUN /docker/install-qe.sh
RUN /docker/run-tests.sh

COPY requirements.txt /tmp/requirements.txt
COPY python/ /opt/qe-python/
RUN pip3 install --no-cache-dir --upgrade pip setuptools wheel && \
    pip3 install --no-cache-dir -r /tmp/requirements.txt && \
    pip3 install --no-cache-dir /opt/qe-python/ && \
    python3 -c "import ase; import qe_ase; print('ASE', ase.__version__, 'qe_ase', qe_ase.__version__)"

RUN /docker/test-ase.sh

RUN useradd -m -s /bin/bash qe && \
    /docker/setup-qe-user.sh && \
    chown -R qe:qe /docker "${QE_ROOT}/tempdir"

USER qe
WORKDIR /home/qe

ENV HOME=/home/qe
ENV PATH=${QE_ROOT}/bin:${PATH}
ENV ESPRESSO_PSEUDO=${QE_ROOT}/pseudo
ENV OMP_NUM_THREADS=4

ENTRYPOINT ["/docker/entrypoint.sh"]
