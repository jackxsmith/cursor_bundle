Vagrant.configure("2") do |config|
  # Ubuntu 25.04 box (custom/ubuntu2504 recommended)
  config.vm.box = "generic/ubuntu2504"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "2048"
    vb.cpus = 2
  end

  # Sync bundle into /vagrant
  config.vm.synced_folder ".", "/vagrant"

  # Provision: install dependencies, run installer and test suite
  config.vm.provision "shell", inline: <<-SHELL
    sudo apt-get update
    sudo apt-get install -y bash curl libfuse2t64 zenity docker.io python3-pip
    pip3 install flask
    cd /vagrant
    # Use the enhanced installer and test suite for version 6.9.32
    bash 14-install_v6.9.32_enhanced.sh
    bash 22-test_cursor_suite_v6.9.32_enhanced.sh
  SHELL
end
