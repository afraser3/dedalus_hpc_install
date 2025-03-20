First, install the miniforge variant of conda. I chose not to let it modify my .bashrc, so instead need to enter 
`eval "$(/home1/03662/aefraser/miniforge3/bin/conda shell.bash hook)"` every time I log in.

Load fftw3/3.3.10 and phdf5/1.14.4 modules

Modify header of dedalus's custom conda install script to point to cluster libraries:
> INSTALL_MPI=0
> 
> export MPI_PATH=$TACC_IMPI_DIR
> 
> INSTALL_FFTW=0
> 
> export FFTW_PATH=$TACC_FFTW3_DIR
> 
> INSTALL_HDF5=0
> 
> export HDF5_DIR=$TACC_PHDF5_DIR
> 
> export HDF5_MPI="ON"
>
> BLAS="mkl"

(trying mkl for now, results TBD)

Also, as a quick fix to [this issue](https://github.com/DedalusProject/dedalus/pull/317) in d2 relating to certain 
things being deprecated in scipy 1.14, I changed `scipy` to `scipy=1.13.1` in the relevant conda install lines. 
Additionally, following [this post](https://groups.google.com/g/dedalus-users/c/HVKP6K5C5n4/m/CZBoA960AgAJ), I 
similarly found the need to change `mpi4py` to `"mpi4py<4.0"` in the install script.