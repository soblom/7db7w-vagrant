# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile API/syntax version. Don't touch unless you know what you're doing!
VAGRANTFILE_API_VERSION = "2"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
  # All Vagrant configuration is done here. The most common configuration
  # options are documented and commented below. For a complete reference,
  # please see the online documentation at vagrantup.com.

  # Every Vagrant virtual environment requires a box to build off of.
  config.vm.box = "ubuntu_cim_1304"
  
  # The url from where the 'config.vm.box' box will be fetched if it
  # doesn't already exist on the user's system.
  config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-i386-vagrant-disk1.box"

  config.vm.network :forwarded_port, guest: 10018, host: 10018   #port for riak

  config.berkshelf.enabled = true
  config.vm.provision :chef_solo do |chef|
    config.omnibus.chef_version = :latest
    chef.log_level = :debug
    chef.add_recipe "7db7w-configure::postgresql"
    # You may also specify custom JSON attributes:
    # chef.json = { :mysql_password => "foo" }
  end

end
