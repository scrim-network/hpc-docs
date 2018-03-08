# MPI Example for Python

## Introduction
In this Python example, we use the [`mpi4py`](http://mpi4py.scipy.org/docs/) Python package to run a parallel computing MPI Python script with a coordinator-worker-writer pattern. The `mpi4py` package provides Python bindings to the underlying MPI C library. The coordinator-worker-writer pattern uses a single coordinator process to coordinate the worker processes and single writer process to write the results. This design can be used to parallize any [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel) workload.    

## Environment Setup
The first step in running the example is to login to an ICS-ACI batch node, setup the environment and install the `mpi4py` Python package.

Login to an ICS-ACI batch node:

```Shell
ssh username@aci-b.aci.ics.psu.edu
```

Before installing `mpi4py`, an MPI implementation must be loaded into the environment so that `mpi4py` has a MPI library to compile against. For this example, we will use the gcc-compiled [OpenMPI](https://www.open-mpi.org) library and Python 3 environment available within the ICS-ACI modules system. At the terminal, run the following `module` command  

```Shell
module load gcc/5.3.1 openmpi/1.10.1 python/3.3.2
```

Next, we need to install a local copy of [pip](https://pip.pypa.io/en/stable/) to install `mpi4py`:

```Shell
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py --user
```

This places a local copy of pip in `~/.local/bin/pip`. Next, use pip to install mpi4py:

```Shell
~/.local/bin/pip install mpi4py --user
```

## Example Python Script
In this example, we have a simple function we want to individually apply to all numbers in a vector. Using coordinator, worker, and writer functions, the script applies the function to the numbers in parallel and then prints out the results. The full script can be found [here](https://github.com/scrim-network/hpc-docs/blob/master/examples/python/mpi4py_coord_work_write/mpi4py_coord_work_write.py). 

Load the required Python packages for the example and define required global constants.

```python
from mpi4py import MPI
import random
import time

TAG_DOWORK = 1
TAG_STOPWORK = 2

RANK_COORD = 0
RANK_WRITE = 1
N_NON_WRKRS = 2

```

Define the function to be run by all worker processes. The function receives work (i.e. a number) from the coordinator, adds random noise to the number, sleeps for 5 seconds, and then sends the result to the writer process.

```python
def proc_work():

    rank = MPI.COMM_WORLD.Get_rank()
    status = MPI.Status()

    while 1:

        a_num = MPI.COMM_WORLD.recv(source=RANK_COORD, tag=MPI.ANY_TAG, status=status)

        if status.tag == TAG_STOPWORK:

            MPI.COMM_WORLD.send(None, dest=RANK_WRITE, tag=TAG_STOPWORK)
            print("".join(["WORKER ", str(rank), ": finished"]))
            return 0

        else:

            # Perform work task
            # Add random number to a_num and sleep for 5 seconds

            y = a_num + random.randint(0,100)
            time.sleep(5)

            # Send result to writer
            MPI.COMM_WORLD.send(y, dest=RANK_WRITE, tag=TAG_DOWORK)

            # Tell coordination process that this worker is now free for
            # additional work.
            MPI.COMM_WORLD.send(rank, dest=RANK_COORD, tag=TAG_DOWORK)
```

Define the function to be run by the writer process. The writer receives results from the workers and prints the results as they are received. This can be changed to write to a file instead.


```python
def proc_write():

    status = MPI.Status()
    rank = MPI.COMM_WORLD.Get_rank()
    nsize = MPI.COMM_WORLD.Get_size()
    nwrkers = nsize - N_NON_WRKRS
    nwrkrs_done = 0

    while 1:

        a_result = MPI.COMM_WORLD.recv(source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG, status=status)

        if status.tag == TAG_STOPWORK:

            nwrkrs_done += 1
            if nwrkrs_done == nwrkers:

                print("WRITER: Finished")
                return 0
        else:

            print("WRITER: Recieved a result. The result is " + str(a_result))
```

Define the function to be run by the coordinator process. The coordinator loops through a set of numbers sending them to the workers for processing. 

```python
def proc_coord():

    nsize = MPI.COMM_WORLD.Get_size()
    nwrkers = nsize - N_NON_WRKRS

    print("COORD: Starting to send work.")

    cnt = 0

    for a_num in range(100):

        if cnt < nwrkers:
            dest = cnt + N_NON_WRKRS
        else:
            dest = MPI.COMM_WORLD.recv(source=MPI.ANY_SOURCE, tag=MPI.ANY_TAG)

        MPI.COMM_WORLD.send(a_num, dest=dest, tag=TAG_DOWORK)
        cnt += 1

    print("COORD: Done sending work.")

    for w in np.arange(nwrkers):
        MPI.COMM_WORLD.send(None, dest=w + N_NON_WRKRS, tag=TAG_STOPWORK)
```

Finally add a main block of code that determines which processes are assigned as the coordinator, workers, and writer and performs the actual execution of the functions.

```python
if __name__ == '__main__':

    rank = MPI.COMM_WORLD.Get_rank()
    nsize = MPI.COMM_WORLD.Get_size()

    if rank == RANK_COORD:
        proc_coord()
    elif rank == RANK_WRITE:
        proc_write()
    else:
        proc_work()

    MPI.COMM_WORLD.Barrier()
```

## Example PBS Script

Here we walk through an example PBS script for submitting the above Python script to the ICS-ACI batch queue. The script includes PBS directives that specify the computing resources required, commands for setting up the required shell environment, and the command for running the Python script. The full script can be found [here](https://github.com/scrim-network/hpc-docs/blob/master/examples/python/mpi4py_coord_work_write/pbs_mpi4py_coord_work_write.sh).

At the top of the script, insert a system shell [shebang](https://en.wikipedia.org/wiki/Shebang_%28Unix%29).

```Shell
#!/bin/sh 
```
Add PBS directives for the computing resources required and other configuration parameters. PBS directives are specified as `#PBS [option]`. As an alternative, these or additional directives can also used as options to the `qsub` command that is used to submit the job.

```Shell
#PBS -l nodes=2:ppn=20
#PBS -l walltime=00:05:00
#PBS -l pmem=1GB
#PBS -j oe
#PBS -o [FILEPATH OF LOG FILE]
#PBS -m abe
#PBS -M [YOUR EMAIL ADDRESS]
```

* `PBS -l` lines (l = "limit") state that we are requesting 2 nodes with 20 processes per node (i.e. 40 total processes), a processing time of 5 minutes, and 1 gigabyte of memory for each process.
* `#PBS -j oe` requests that the standard out and standard error streams of the PBS job script should be joined together and written to a single file.
* `#PBS -j o` specifies the file path for the PBS script log file where standard out and error will be written. This is where the writer process will write the results. 
* `#PBS -m abe` requests that an email be sent when the job begins (b), ends (e), or aborts (a) 
* `#PBS -M` specifies the email address to which the status emails will be sent

By default, execution of the PBS script will occur within your home directory. To execute the script from the directory from which you submitted the job, `cd` into the directory using the `$PBS_O_WORKDIR` PBS environmental variable:

```Shell
cd $PBS_O_WORKDIR
```

Add a `modules` command to load the required MPI library and Python environment.

```Shell
module load gcc/5.3.1 openmpi/1.10.1 python/3.3.2
```

Finally, add the command that executes the Python script

```Shell
mpiexec -np 40 -machinefile $PBS_NODEFILE python -u mpi4py_coord_work_write.py
```
Programs that use MPI must be executed with the [`mpiexec`](https://www.open-mpi.org/doc/current/man1/mpiexec.1.php) command. In this example we specificy three `mpiexec` parameters:

* `-np` Specifies the number of processes. Here, we are requesting 40 processes to match what was requested with the PBS directive. Because we need one process as a coordinator and one as a writer, there will be 38 total workers performing the actual computation. 
* `-machinefile` Specifies a file containing the list of nodes on which the processes should be run. PBS automatically determines the nodes that the job will run on and places the node hostnames in a file pointed to by the `$PBS_NODEFILE` environmental variable.
* `python -u mpi4py_coord_work_write.py` The actual command for running the Python script. The `-u` option to python is for unbuffered output.

The job can then be submited to a ICS-ACI queue using the qsub command:

```Shell
qsub -A open pbs_mpi4py_coord_work_write.sh
```     
* `-A` specifies the account under which the job should be executed. Here, we are using the free ICS-ACI open account. Alternatively, this can be specified as a directive in the PBS script.
* `pbs_mpi4py_coord_work_write.sh` the name of the PBS script