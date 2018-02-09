# MPI Example for R using the foreach looping contruct
# See documentation at: https://github.com/scrim-network/hpc-docs/blob/master/examples/R/foreach_mpi/foreach_mpi.md

# Load libraries
library(Rmpi)
library(doParallel)
library(foreach)

# Set the output file paths for a log file and the RData results file.
fpath_log <- "[FILE PATH TO LOG FILE]"
fpath_out <- "[FILE PATH FOR RDATA FILE TO WRITE RESULTS]"
# Specify the number of processes to use. This should be one less than what is
# requested in the accompanying PBS script because we need to count the main process.
nprocs <- 19

# Specify the underlying multiprocessing implementation. In this case, we are
# using MPI. If running on a single computer, "PSOCK" can also be used.
mp_type = "MPI" # PSOCK or MPI

# Define the function to be applied to each number. In this very simple example,
# the function adds random noise to the number, sleeps for 5 seconds and then returns
# the result. The function also writes out the result to a log file. We use a
# log file instead of simple print commands, because print commands from the worker
# processes will not show on standard out. The function takes both the number and log file path as input.
a_func <- function(x, fpath_log) {

  y <- x + runif(1)
  Sys.sleep(5)
  log_file <-file(fpath_log, open='a')
  writeLines(sprintf("Processed %d. Result: %.3f", x, y), log_file)
  flush(log_file)

  return(y)
}

# Initialize the output log file
writeLines(c(""), fpath_log)

# Initialize the parallel worker processes. Be aware that each worker will be
# initialized with the R environment of the main process. This can be useful when
# there are certain global data structures for which each worker process needs
# access. The data can be loaded into the memory of the main process and then when
# the parallel worker processes are initialized, the data structures will be
# automatically copied out to the memory associated with each worker process.
# However, be cautious about memory issues. If you have a lot of data loaded in
# the main process, it will be duplicated in each of the worker processes.
cl <- parallel::makeCluster(nprocs, type=mp_type)
doParallel::registerDoParallel(cl)

# Loop through the numbers to be processed using the foreach looping contruct.
# The numbers will be sent to the workers and processed in parallel.
# All results will be gathered in a single "results" list object.
args_seq <- seq(100)
results <- foreach::foreach(a_arg=args_seq) %dopar% {

  a_func(a_arg, fpath_log)

}

# Stop the worker processes
stopCluster(cl)

# Save the results to the output RData file.
save(results, file=fpath_out)

# Write "processing complete" to the log file.
log_file <-file(fpath_log, open='a')
writeLines(sprintf("Processing complete. Results written to %s", log_file), fpath_out)
flush(log_file)
close(log_file)
