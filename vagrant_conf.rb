module SharedVagrantSettings
  
  def self.configure(config)
    # All Vagrant configuration is done here. The most common configuration
    # options are documented and commented below. For a complete reference,
    # please see the online documentation at vagrantup.com.

    # Every Vagrant virtual environment requires a box to build off of.
    config.vm.box = "ubuntu_cim_1304"

    # The url from where the 'config.vm.box' box will be fetched if it
    # doesn't already exist on the user's system.
    config.vm.box_url = "http://cloud-images.ubuntu.com/vagrant/raring/current/raring-server-cloudimg-i386-vagrant-disk1.box"

    config.vm.synced_folder '../exercises', "/home/vagrant/7db7w"

    config.vm.network :forwarded_port, guest: 10018, host: 10018   #port for riak
  end

  
end