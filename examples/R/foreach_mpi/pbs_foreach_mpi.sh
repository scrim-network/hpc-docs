#!/bin/sh

#PBS -l nodes=2:ppn=20
#PBS -l walltime=00:05:00
#PBS -l pmem=1GB
#PBS -j oe
#PBS -o foreach_mpi_pbs.log
#PBS -m abe
#PBS -M jwo118@psu.edu

cd $PBS_O_WORKDIR

module load gcc/5.3.1 openmpi/1.10.1

mpiexec -np 1 -machinefile $PBS_NODEFILE Rscript foreach_mpi.R
