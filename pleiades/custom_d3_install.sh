#!/usr/bin/env bash

# Dedalus stack builder using conda, with options for own MPI and FFTW.
# Run this file after installing conda and activating the base environment.

#############
## Options ##
#############

# Conda environment name
CONDA_ENV="d3"

# Skip conda prompts
CONDA_YES=1

# Quiet conda output
CONDA_QUIET=1

# Install openmpi from conda, otherwise MPI_PATH must be set
INSTALL_MPI=0
export MPI_PATH=$MPI_ROOT

# Install fftw from conda, otherwise FFTW_PATH must be set
INSTALL_FFTW=0
export FFTW_PATH=/home1/eanders/builddir/conda_install/fftw_install_new
#export FFTW_PATH=/nasa/intel/Compiler/2020.4.304/mkl/include/fftw/
#export FFTW_PATH=$PKGSRC_BASE

# Install HDF5 from conda, otherwise HDF5_DIR must be set to your custom HDF5 prefix
# Note: HDF5 from conda will only be built with parallel support if MPI is installed from conda
# Note: If your custom HDF5 is built with parallel support, HDF5_MPI must be set to "ON"
INSTALL_HDF5=0
export HDF5_DIR=/home1/eanders/builddir/conda_install/hdf5_install
export HDF5_MPI="ON"


# BLAS options for numpy/scipy: "openblas" or "mkl"
#BLAS="openblas"
BLAS="mkl"

# Python version
PYTHON_VERSION="3.8"

############
## Script ##
############

# Check requirements
if [ "${CONDA_DEFAULT_ENV}" != "base" ]
then
    >&2 echo "ERROR: Conda base environment must be activated"
    exit 1
fi

if [ ${INSTALL_MPI} -ne 1 ]
then
    if [ -z ${MPI_PATH} ]
    then
        >&2 echo "ERROR: MPI_PATH must be set"
        exit 1
    else
        echo "MPI_PATH set to '${MPI_PATH}'"
    fi
fi

if [ ${INSTALL_FFTW} -ne 1 ]
then
    if [ -z ${FFTW_PATH} ]
    then
        >&2 echo "ERROR: FFTW_PATH must be set"
        exit 1
    else
        echo "FFTW_PATH set to '${FFTW_PATH}'"
    fi
fi

if [ ${INSTALL_HDF5} -ne 1 ]
then
    if [ -z ${HDF5_DIR} ]
    then
        >&2 echo "ERROR: HDF5_DIR must be set"
        exit 1
    else
        echo "HDF5_DIR set to '${HDF5_DIR}'"
        echo "HDF5_MPI set to '${HDF5_MPI}'"
    fi
fi


prompt_to_proceed () {
    while true; do
        read -p "Proceed ([y]/n)? " proceed
        case "${proceed}" in
            "y" | "") break ;;
            "n") exit 1 ;;
            *) ;;
        esac
    done
}

CARGS=(-n ${CONDA_ENV})
if [ ${CONDA_YES} -eq 1 ]
then
    CARGS+=(-y)
fi
if [ ${CONDA_QUIET} -eq 1 ]
then
    CARGS+=(-q)
fi

echo "Setting up conda with 'source ${CONDA_PREFIX}/etc/profile.d/conda.sh'"
source ${CONDA_PREFIX}/etc/profile.d/conda.sh

echo "Preventing conda from looking in ~/.local with 'export PYTHONNOUSERSITE=1'"
export PYTHONNOUSERSITE=1

echo "Preventing conda from looking in PYTHONPATH with 'unset PYTHONPATH'"
unset PYTHONPATH

# Check if conda environment exists
conda activate ${CONDA_ENV} >&/dev/null
if [ $? -eq 0 ]
then
    echo "WARNING: Conda environment '${CONDA_ENV}' already exists"
    prompt_to_proceed
else
    echo "Building new conda environment '${CONDA_ENV}'"
    conda create "${CARGS[@]}" -c conda-forge "python=${PYTHON_VERSION}"
    conda activate ${CONDA_ENV}
fi

echo "Updating conda-forge pip, wheel, setuptools, cython"
conda install "${CARGS[@]}" -c conda-forge pip wheel setuptools cython

case "${BLAS}" in
"openblas")
    echo "Installing conda-forge openblas, numpy, scipy"
    conda install "${CARGS[@]}" -c conda-forge "libblas=*=*openblas" numpy scipy
    # Dynamically link FFTW
    export FFTW_STATIC=0
    ;;
"mkl")
    echo "Installing conda-forge mkl, numpy, scipy"
    conda install "${CARGS[@]}" -c conda-forge "libblas=*=*mkl" numpy scipy
    # Statically link FFTW to avoid MKL symbols
    export FFTW_STATIC=1
    ;;
*)
    >&2 echo "ERROR: BLAS must be 'openblas' or 'mkl'"
    exit 1
    ;;
esac

if [ ${INSTALL_MPI} -eq 1 ]
then
    echo "Installing conda-forge compilers, openmpi, mpi4py"
    conda install "${CARGS[@]}" -c conda-forge compilers openmpi openmpi-mpicc mpi4py
else
    echo "Not installing openmpi"
    echo "Installing mpi4py with pip"
    # Make sure mpicc will appear on path
    export PATH=${MPI_PATH}/bin:${PATH}
    echo "which mpicc: `which mpicc`"
    # no-cache to avoid wheels from previous pip installs
    python3 -m pip install --no-cache mpi4py
fi

if [ ${INSTALL_FFTW} -eq 1 ]
then
    echo "Installing conda-forge fftw"
    # no-deps to avoid pulling openmpi
    conda install "${CARGS[@]}" -c conda-forge --no-deps "fftw=*=*openmpi*"
else
    echo "Not installing fftw"
fi

if [ ${INSTALL_HDF5} -eq 1 ]
then
    if [ ${INSTALL_MPI} -eq 1 ]
    then
        echo "Installing parallel conda-forge hdf5, h5py"
        conda install "${CARGS[@]}" "hdf5=*=mpi*" "h5py=*=mpi*"
    else
        echo "Installing serial conda-forge hdf5, h5py"
        conda install "${CARGS[@]}" "hdf5=*=nompi*" "h5py=*=nompi*"
    fi
else
    echo "Not installing hdf5"
    if [ ${HDF5_MPI} == "ON" ]
    then
        echo "Installing parallel h5py with pip"
        # CC=mpicc to build with parallel support
        # no-cache to avoid wheels from previous pip installs
        # no-binary to build against linked hdf5
        CC=mpicc python3 -m pip install --no-cache --no-binary=h5py h5py
    else
        echo "Installing serial h5py with pip"
        # no-cache to avoid wheels from previous pip installs
        # no-binary to build against linked hdf5
        python3 -m pip install --no-cache --no-binary=h5py h5py
    fi
fi

echo "Installing conda-forge docopt, matplotlib"
conda install "${CARGS[@]}" -c conda-forge docopt matplotlib


# conda install umfpack
echo "Conda installing umfpack"
conda install "${CARGS[@]}" -c conda-forge scikit-umfpack

echo "Installing dedalus with pip"
# CC=mpicc to ensure proper MPI linking
# no-cache to avoid wheels from previous pip installs
CC=mpicc python3 -m pip install --no-cache http://github.com/dedalusproject/dedalus/zipball/master/


#echo "Installing dedalus with pip"
## no-cache to avoid wheels from previous pip installs
## no-build-isolation to use established stack for building wheel
#git clone https://github.com/DedalusProject/dedalus.git src/dedalusv3
#python3 -m pip install --no-cache --no-build-isolation -e src/dedalusv3


echo "Installation complete in conda environment '${CONDA_ENV}'"
conda deactivate
