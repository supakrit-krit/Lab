Lab2: HPC
=========

Requirements
------

- /home: 100G thin LVM share
- nfs quota
- nfs access control list
- ssh passwordless: public key authen
- sudoer on freeIPA
- Grafana, Prometheus, node-exporter
- Notify
- HPC Architecture
    - Head node
        - FreeIPA        - NFS Server
        - 2 Network (public, private)
    - Compute node
        - only private network

Head Node (192.168.30.141): head:lab2password
    - Having FreeIPA, NFS Server

LVM
------

Q: [Thick and Thin Provisioning: What Is the Difference?](https://www.nakivo.com/blog/thick-and-thin-provisioning-difference/)

- Thick provisioning is a type of storage pre-allocation. With thick provisioning, the complete amount of virtual disk storage capacity is pre-allocated on the physical storage when the virtual disk is created. A thick-provisioned virtual disk consumes all the space allocated to it in the datastore right from the start, so the space is unavailable for use by other virtual machines.

- Thin provisioning is another type of storage pre-allocation. A thin-provisioned virtual disk consumes only the space that it needs initially, and grows with time according to demand. For example, if you create a new thin-provisioned 30GB virtual disk and copy 10 GB of files to it, the size of the resulting VMDK file will be 10 GB, whereas you would have a 30GB VMDK file if you had chosen to use a thick-provisioned disk.


>Reference: 
>1.	https://datarecoverylab.wordpress.com/2010/05/09/hard-drive-bus-types-scsi-sata-esata-ide-sas-and-firewire-ieee-1394/