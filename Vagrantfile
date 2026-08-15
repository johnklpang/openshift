# frozen_string_literal: true

# OpenShift lab VMs: 1 master + 3 workers on VirtualBox.
# Optional helper VM provides DNS, HAProxy, and a bastion for later UPI install.
#
#   vagrant up
#   LAB_PROFILE=install vagrant up    # larger RAM; needs ~32 GB host
#   LAB_HELPER=false vagrant up       # cluster nodes only
#
# These VMs are prepared for OpenShift. They are not an installed cluster.

PROFILE = ENV.fetch("LAB_PROFILE", "prep")
ENABLE_HELPER = ENV.fetch("LAB_HELPER", "true") != "false"
BOX = ENV.fetch("LAB_BOX", "bento/rockylinux-9")
DOMAIN = ENV.fetch("LAB_DOMAIN", "ocp.lab.local")
NETWORK = ENV.fetch("LAB_NETWORK", "192.168.56")

PROFILES = {
  "prep" => {
    "helper" => { cpus: 1, memory: 1024, disk: 20 },
    "master" => { cpus: 2, memory: 2048, disk: 40 },
    "worker" => { cpus: 1, memory: 1536, disk: 30 }
  },
  "install" => {
    "helper" => { cpus: 2, memory: 2048, disk: 40 },
    "master" => { cpus: 4, memory: 8192, disk: 80 },
    "worker" => { cpus: 2, memory: 6144, disk: 60 }
  }
}.freeze

abort "Unknown LAB_PROFILE=#{PROFILE}. Use prep or install." unless PROFILES.key?(PROFILE)

SIZES = PROFILES[PROFILE]
HELPER_IP = "#{NETWORK}.9"
MASTER_IP = "#{NETWORK}.10"
WORKERS = {
  "worker1" => "#{NETWORK}.11",
  "worker2" => "#{NETWORK}.12",
  "worker3" => "#{NETWORK}.13"
}.freeze

def provision_common(node, hostname, ip, role)
  node.vm.provision "shell", path: "vagrant/provision/common.sh",
                    args: [hostname, ip, role, DOMAIN, NETWORK]
end

Vagrant.configure("2") do |config|
  config.vm.box = BOX
  config.vm.box_check_update = false
  config.vm.synced_folder ".", "/vagrant", disabled: true
  config.ssh.insert_key = true

  config.vm.provider "virtualbox" do |vb|
    vb.gui = false
    vb.linked_clone = true
    vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
    vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    vb.customize ["modifyvm", :id, "--audio", "none"]
  end

  if ENABLE_HELPER
    config.vm.define "helper", primary: true do |helper|
      helper.vm.hostname = "helper.#{DOMAIN}"
      helper.vm.network "private_network", ip: HELPER_IP
      helper.vm.provider "virtualbox" do |vb|
        vb.name = "ocp-helper"
        vb.cpus = SIZES["helper"][:cpus]
        vb.memory = SIZES["helper"][:memory]
      end
      provision_common(helper, "helper", HELPER_IP, "helper")
      helper.vm.provision "file", source: "vagrant/files/haproxy.cfg",
                          destination: "/tmp/haproxy.cfg"
      helper.vm.provision "file", source: "vagrant/files/dnsmasq.conf",
                          destination: "/tmp/dnsmasq.conf"
      helper.vm.provision "shell", path: "vagrant/provision/helper.sh",
                          args: [DOMAIN, HELPER_IP, MASTER_IP, *WORKERS.values]
    end
  end

  config.vm.define "master" do |master|
    master.vm.hostname = "master.#{DOMAIN}"
    master.vm.network "private_network", ip: MASTER_IP
    master.vm.provider "virtualbox" do |vb|
      vb.name = "ocp-master"
      vb.cpus = SIZES["master"][:cpus]
      vb.memory = SIZES["master"][:memory]
    end
    provision_common(master, "master", MASTER_IP, "master")
    master.vm.provision "shell", path: "vagrant/provision/master.sh"
  end

  WORKERS.each do |name, ip|
    config.vm.define name do |worker|
      worker.vm.hostname = "#{name}.#{DOMAIN}"
      worker.vm.network "private_network", ip: ip
      worker.vm.provider "virtualbox" do |vb|
        vb.name = "ocp-#{name}"
        vb.cpus = SIZES["worker"][:cpus]
        vb.memory = SIZES["worker"][:memory]
      end
      provision_common(worker, name, ip, "worker")
      worker.vm.provision "shell", path: "vagrant/provision/worker.sh"
    end
  end
end
