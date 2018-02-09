# MPI Example for R

## Introduction
In this R example, we use the [`foreach`](https://cran.r-project.org/web/packages/foreach/) R package interface to run a parallel computing MPI R script. The `foreach` package provides a looping construct that can use MPI to parallize an [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel) workload. While this isn't a very flexible approach, it hides much of the complexity of MPI and allows for the use of a "for loop" that is familiar to many programmers.   

## Environment Setup
The first step in running the example is to login to an ICS-ACI batch node, setup the environment and install the required R packages. The following R packages are required:

* [`Rmpi`](https://cran.r-project.org/web/packages/Rmpi/index.html): provides underlying wrapper interface to MPI
* [`foreach`](https://cran.r-project.org/web/packages/foreach): provides looping construct that supports parallel execution
* [`doParallel`](https://cran.r-project.org/web/packages/doParallel/index.html): provides parallel backend to `foreach`
* [`snow`](https://cran.r-project.org/web/packages/snow/index.html): provides additional underlying functionality for interfacing with `Rmpi`

Login to an ICS-ACI batch node:

```Shell
ssh username@aci-b.aci.ics.psu.edu
```

Before installing the R packages, an MPI implementation must be loaded into the environment so that `Rmpi` has a MPI library to compile against. For this example, we will use the gcc-compiled [OpenMPI](https://www.open-mpi.org) library available within the ICS-ACI modules system. At the terminal, run the following `module` command  

```Shell
module load gcc/5.3.1 openmpi/1.10.1
```

Next, launch R and install `Rmpi` including configuration arguments for the OpenMPI library:

```R
install.packages('Rmpi', configure.args=c('--with-Rmpi-include=/opt/aci/sw/openmpi/1.10.1_gcc-5.3.1/include','--with-Rmpi-libpath=/opt/aci/sw/openmpi/1.10.1_gcc-5.3.1/lib','--with-Rmpi-type=OPENMPI'))

```

Install the remaining required packages:

```R
install.packages(c('doParallel','foreach','snow'))
```

## Example R Script
In this example, we have a simple function we want to individually apply to all numbers in a vector. The script applies the function to the numbers in parallel and then writes out the results as an RData file. This design can be used to parallize any [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel) workload.

Load the required libraries.

```R
library(Rmpi)
library(doParallel)
library(foreach)
```

Set the output file paths for a log file and the RData results file.

```R
fpath_log <- "[FILE PATH TO LOG FILE]"
fpath_out <- "[FILE PATH FOR RDATA FILE TO WRITE RESULTS]"
```

Specify the number of processes to use. This should be one less than what is requested in the accompanying PBS script because we need to count the main process.

```R
nprocs <- 39
```

Specify the underlying multiprocessing implementation. In this case, we are using MPI. If running on a single computer, "PSOCK" can also be used.

```R
mp_type <- "MPI"
```

Define the function to be applied to each number. In this very simple example, the function adds random noise to the number, sleeps for 5 seconds and then returns the result. The function also writes out the result to a log file. We use a log file instead of simple print commands, because print commands from the worker processes will not show on standard out. The function takes both the number and log file path as input. 

```R
a_func <- function(x, fpath_log) {

  y <- x + runif(1)
  Sys.sleep(5)
  log_file <-file(fpath_log, open='a')
  writeLines(sprintf("Processed %d. Result: %.3f", x, y), log_file)
  flush(log_file)

  return(y)
}
```

Initialize the output log file.

```R
writeLines(c(""), fpath_log)
```

Initialize the parallel worker processes. Be aware that each worker will be initialized with the R environment of the main process. This can be useful when there are certain global data structures for which each worker process needs access. The data can be loaded into the memory of the main process and then when the parallel worker processes are initialized, the data structures will be automatically copied out to the memory associated with each worker process. However, be cautious about memory issues. If you have a lot of data loaded in the main process, it will be duplicated in each of the worker processes. 

```R
cl <- parallel::makeCluster(nprocs, type=mp_type)
doParallel::registerDoParallel(cl)
```

Loop through the numbers to be processed using the `foreach` looping contruct. The numbers will be sent to the workers and processed in parallel. All results will be gathered in a single "results" list object.

```R
args_seq <- seq(100)
results <- foreach::foreach(a_arg=args_seq) %dopar% {

  a_func(a_arg, fpath_log)

}
```

Stop the worker processes.

```R
stopCluster(cl)
```

Save the results to the output RData file.

```R
save(results, file=fpath_out)
```

Write "processing complete" to the log file.

```R
log_file <-file(fpath_log, open='a')
writeLines(sprintf("Processing complete. Results written to %s", fpath_out), log_file)
flush(log_file)
close(log_file)
```

## Example PBS Script

Here we walkthrough an example PBS script for submitting the above R script to the ICS-ACI batch queue. The script includes PBS directives that specify the computing resources required, commands for setting up the required shell environment, and the command for running the R script.

Start the script with a system shell [shebang](https://en.wikipedia.org/wiki/Shebang_%28Unix%29).

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
* `#PBS -j o` specifies the file path for the PBS script log file. Note: this is different than the log file specified in the R script. 
* `#PBS -m abe` requests that an email be sent when the job begins (b), ends (e), or aborts (a) 
* `#PBS -M` specifies the email address to which the status emails will be sent

By default, execution of the PBS script will occur within your home directory. To execute the script from the directory from which you submitted the job, `cd` into the directory using the `$PBS_O_WORKDIR` PBS environmental variable:

```Shell
cd $PBS_O_WORKDIR
```

Add a `modules` command to load the required MPI library.
```Shell
module load gcc/5.3.1 openmpi/1.10.1
```

Finally, add the command that executes the R script

```Shell
mpiexec -np 1 -machinefile $PBS_NODEFILE Rscript foreach_mpi.R
```
Programs that use MPI must be executed with the [`mpiexec`](https://www.open-mpi.org/doc/current/man1/mpiexec.1.php) command. In this example we specificy three `mpiexec` parameters:

* `-np` Specifies the number of processes. **Important: Typically, this should match the number of processes requested in the PBS directive. However, due to how MPI is used by the `foreach` looping contruct, `-np` needs to be set to 1 for this example**. Unlike a typical MPI use case, the number of processes spawned is controlled directly by the `nprocs` variable that we defined in the example R script. If `-np` is set to 40 by accident, a big mess will be created: 40 R processes will be kicked off and then each of these processes will spawn 39 processes resulting in a total of 1560 processes! 
* `-machinefile` Specifies a file containing the list of nodes on which the processes should be run. PBS automatically determines the nodes that the job will run on and places the node hostnames in a file pointed to by the `$PBS_NODEFILE` environmental variable.
* `Rscript foreach_mpi.R` The actual command for running the R script. `Rscript` is a standard command for executing an R script and `foreach_mpi.R` is the name of the script file.

The job can then be submited to a ICS-ACI queue using the qsub command:

```Shell
qsub -A open pbs_foreach_mpi.sh
```     
* `-A` specifies the account under which the job should be executed. Here, we are using the free ICS-ACI open account. Alternatively, this can be specified as a directive in the PBS script.
* `pbs_foreach_mpi.sh` the name of the PBS script