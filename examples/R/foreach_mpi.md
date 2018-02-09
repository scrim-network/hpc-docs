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
nprocs <- 19
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

Stop the work processes.

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
writeLines(sprintf("Processing complete. Results written to %s", log_file), log_file)
flush(log_file)
close(log_file)
```