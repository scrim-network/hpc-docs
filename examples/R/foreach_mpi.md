# MPI Example for R

In this R example, we use the [`foreach`](https://cran.r-project.org/web/packages/foreach/) `R` package interface to run a parallel computing MPI `R` script. The `foreach` package provides a looping construct that can use MPI to parallize an [embarrassingly parallel](https://en.wikipedia.org/wiki/Embarrassingly_parallel) workload. While this isn't a very flexible approach, it hides much of the complexity of MPI and allows for the use of a "for loop" that is familiar to any programmer.   

The first step in running the example is to login to an ICS-ACI batch node, setup the environment and install the required R packages. The following R packages are required:

* [`Rmpi`](https://cran.r-project.org/web/packages/Rmpi/index.html)
* [`foreach`](https://cran.r-project.org/web/packages/foreach)
* [`doParallel`](https://cran.r-project.org/web/packages/doParallel/index.html)
* [`snow`](https://cran.r-project.org/web/packages/snow/index.html)

Login to an ICS-ACI batch node:

```Shell
ssh username@aci-b.aci.ics.psu.edu
```

Before installing the `R` packages, an MPI implementation must be loaded into the environment so that `Rmpi` has a MPI library to compile against. For this example, we will use the gcc-compiled `OpenMPI` library available within the ICS-ACI modules system. At the terminal, run the following `module` command  

```Shell
module load gcc/5.3.1 openmpi/1.10.1
```

Next, launch `R` and install `Rmpi` including configuration arguments for the `OpenMPI` library:

```R
install.packages('Rmpi',configure.args=c('--with-Rmpi-include=/opt/aci/sw/openmpi/1.10.1_gcc-5.3.1/include','--with-Rmpi-libpath=/opt/aci/sw/openmpi/1.10.1_gcc-5.3.1/lib','--with-Rmpi-type=OPENMPI'))

```

Install the remaining required packages:

```R
install.packages(c('doParallel','foreach','snow'))
```
