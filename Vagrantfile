# -*- mode: ruby -*-
# vi: set ft=ruby :

VAGRANTFILE_API_VERSION = "2"

Vagrant::Config.run do |config|

  config.vm.box = "precise64"
  config.vm.box_url = "http://files.vagrantup.com/precise64.box"
  config.vm.host_name = "santoku"
  
  config.ssh.forward_agent = true
end


Vagrant::VERSION >= "1.1.0" and Vagrant.configure("2") do |config|
  config.vm.hostname = "santoku"
  
	# Boot with a GUI so you can see the screen. (Default is headless)
	# config.vm.boot_mode = :gui
  config.vm.provider "virtualbox" do |vb, override|
    vb.name = "santoku"
    vb.gui = true
    
    override.vm.synced_folder ".", "/vagrant"
    override.vm.provision :shell, path: "provision.sh"
  end

  # Create a forwarded port mapping which allows access to a specific port
  # within the machine from a port on the host machine. In the example below,
  # accessing "localhost:8080" will access port 80 on the guest machine.
  config.vm.network :forwarded_port, guest: 5037, host: 5037, auto_correct: true # Android ADB port
  
end
