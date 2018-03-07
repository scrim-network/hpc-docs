'''
Example Python script using mpi4py to process a workload using one coordination
process, multiple worker processes, and a writer process.

Must be run using mpiexec or mpirun.
'''

from mpi4py import MPI
import random
import time

TAG_DOWORK = 1
TAG_STOPWORK = 2

RANK_COORD = 0
RANK_WRITE = 1
N_NON_WRKRS = 2

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
