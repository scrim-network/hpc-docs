#!/bin/sh

#PBS -l nodes=2:ppn=20
#PBS -l walltime=00:05:00
#PBS -l pmem=1GB
#PBS -j oe
#PBS -o [FILEPATH OF LOG FILE]
#PBS -m abe
#PBS -M [YOUR EMAIL ADDRESS]

cd $PBS_O_WORKDIR

module load gcc/5.3.1 openmpi/1.10.1 python/3.3.2

mpiexec -np 40 -machinefile $PBS_NODEFILE python -u mpi4py_coord_work_write.py
