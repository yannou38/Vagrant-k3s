A simple VagrantFile that will create a cluster of K3s nodes with a master and 3 workers

NEEDS to be run by running create.sh, because we need to export some data from the master VM and inject in the workers, and this is not feasible with a standard vagrant creation