# Example of using foreach with MPI. Within a PBS job script on ACI, the script
# needs to be executed using mpirun as follows:
#
# mpirun -np 1 -machinefile $PBS_NODEFILE Rscript foreach_mpi.R
#
# The one gotcha with this command is that the number of processes for mpirun
# needs to be 1 (-np 1). Typically, the number of processes that the job actually uses
# would be placed here. However, the foreach example here is different in that
# Rmpi controls the initialization and farming out of the processes using MPI spawn.
#
# Required R packages
# doParallel
# foreach
# Rmpi
# snow

# Load libraries
library(Rmpi)
library(doParallel)
library(foreach)

# File path for log file and output file
fpath_log <- "[FILE PATH TO LOG FILE]"
fpath_out <- "[FILE PATH FOR RDATA FILE TO WRITE RESULTS]"
# The number of processes. Should be one less than what is requested in the PBS
# script, because the main process counts as a process
nprocs <- 19
# The underlying multiprocessing implementation. If running across nodes, use
# MPI. If running on just a single node, PSOCK can be used
mp_type = "MPI" # PSOCK or MPI

# The main function that each process worker will execute
# In this case, the function is simply adding a random number to the parameter
# x and then sleeping for 5 seconds.
a_func <- function(x) {

  y <- x + runif(1)
  Sys.sleep(5)
  log_file <-file(fpath_log, open='a')
  writeLines(sprintf("Processed %d. Result: %.3f", x, y), log_file)
  flush(log_file)

  return(y)
}

# Initialize output log file. We use a log file instead of simple print statements
# because print statements from within the process workers will not show on stdout
writeLines(c(""), fpath_log)

# Initialize the process workers. Each worker will be initialized with the current
# R environment in the main process.
cl <- parallel::makeCluster(nprocs, type=mp_type)
doParallel::registerDoParallel(cl)

# Loop through the workloads to be processed and send them to the workers. In this
# case, all results will be gathered in a single "results" list object
args_seq <- seq(100)
results <- foreach::foreach(a_arg=args_seq) %dopar% {

  a_func(a_arg)

}

# Stop the worker processes
stopCluster(cl)

# Save the results
save(results, file=fpath_out)

# Write process complete to log file
log_file <-file(fpath_log, open='a')
writeLines(sprintf("Processing complete. Results written to %s", log_file), log_file)
flush(log_file)
close(log_file)
