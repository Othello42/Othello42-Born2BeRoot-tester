# Othello42-Born2BeRoot-tester

## Setting up
Ensure Virtual machine is running.

Ensure Virtual machine disk is unlocked.

Ensure SSH is active and allows port 4242.


## Running
Test basic test through ssh:

bash debian_test.sh [username]



Test full test from virtual machine:

hypervisor:        bash debian_test.sh -c [username]

virtual machine:   bash debian_test [username]
