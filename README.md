7db7w-vagrant
=============

Vagrant setup for the environment necessary to follow the "Seven Databases in Seven Weeks" book by E. Redmond and J.R. Wilson.

The books presents (wait for it) seven databases and expects the reader to follow along "hands on" as well as finish practical assignments to deepen understanding. 

The seven databases are

 - PostgreSQL (implemented)
 - Riak	(implemented)
 - HBases (to do)
 - MongoDB (to do)
 - CouchDB (to do)
 - Neo4J (to do)
 - Redis (to do)
 
_(While my implementation is ongoing I have indicated in paranthesis the state of implementation of the individual setups)_
 
The authors target readers with at least intermediate understanding of system administration so that they do not need to spend time on explaining installation and configuration of the databases and surrounding tools.

I started this little project because I wanted to be able to document for myself how I did the set up and also as little ètude in vagrant and configuration management. Others you work through the book might find it helpful to get started quickly or to look into the source and get some idea how I did the setup.

## Installation

You will need to install [Vagrant](http://www.vagrant.com) as well as [VirtualBox](https://www.virtualbox.org/) to make use of this.

Then simply create a directory in which want to keep all your files related to the book and clone this repository.

```(shell)
$ mkdir 7db7w
$ cd 7db7w
$ git clone git@github.com:soblom/7db7w-vagrant.git
```

## Usage

Once everything is set up correctly, everything is handled by Vagrant. You should be possible to get by just following the instructions below. If you want to understand more about what happens have a look at the [vagrant docs](http://docs.vagrantup.com/v2/).

### Setup and Start a VM
To get a virtual machine running, navigate to your project folder (see above) and simply type

```(shell)
$ vagrant up
```

If this is the first run, it will take a long time, as Vagrant has to do the following steps

 1. Download the "base box". The base box is an Ubuntu image and has several hundreds megabytes.
 2. Turn it into a virtual box machine and boot it
 3. Execute all the provisioning scripts. Which in some cases means download and build databases from source

Once the VM is booted, you can access it by simply typing

```(shell)
$ vagrant ssh
```

This gets you into the VM as user `vagrant`. This is the user you will do all your excercises with.

### Stopping a VM

To stop the VM between sittings you might want to free some RAM and save the CPU cycles (although an idling VM is not really consuming too many of those). This can be done without loosing any of the VMs state by _halting_ it or _suspending_ the VM. 

**TBC**...
