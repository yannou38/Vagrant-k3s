# -*- mode: ruby -*-
# vi: set ft=ruby :

$script_master = <<-SCRIPT_MASTER_NODE

#create USER user and add it to the k3s-admin group
sudo adduser USER --disabled-password --gecos ""
echo 'USER:PASSWORD' | sudo chpasswd
sudo addgroup k3s-admin
sudo adduser USER k3s-admin
sudo usermod -a -G k3s-admin USER
echo "USER  ALL=(ALL:ALL) ALL" | sudo tee --append /etc/sudoers

#install k3s
curl -sfL https://get.k3s.io | sh -
sudo chgrp k3s-admin /etc/rancher/k3s/k3s.yaml
sudo chmod g+r /etc/rancher/k3s/k3s.yaml
sudo chmod 777 /etc/rancher/k3s/k3s.yaml #debug
#VM conf for k3s
sudo sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf

#switch to USER and conf his bashrc
sudo su USER
echo 'export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export AKRI_HELM_CRICTL_CONFIGURATION="--set kubernetesDistro=k3s"
echo "PASSWORD" | sudo -S  chmod g+r /etc/rancher/k3s/k3s.yaml
export PATH="$PATH:/home/USER/.local/bin"' | sudo tee --append /home/USER/.bashrc
source /home/USER/.bashrc
#env

echo "PASSWORD" | sudo -S -v 
#install docker
curl -fsSL https://get.docker.com | bash
#install helm
curl -L https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
#install private insecure registry in cluster, configure k3s, docker and system to use it
echo "---
apiVersion: v1
kind: Namespace
metadata:
  name: docker-registry
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: docker-pvc
  namespace: docker-registry
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: local-path
  resources:
    requests:
      storage: 2Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: docker-registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
        name: registry
    spec:
      containers:
      - name: registry
        image: registry:2
        ports:
        - containerPort: 5000
        volumeMounts:
        - name: docker-pvc
          mountPath: /var/lib/registry
      volumes:
      - name: docker-pvc
        persistentVolumeClaim:
          claimName: docker-pvc
---
apiVersion: v1
kind: Service
metadata:
  name: registry-service
  namespace: docker-registry
spec:
  selector:
    app: registry
  type: LoadBalancer
  ports:
    - name: docker-port
      protocol: TCP
      port: 5000
      targetPort: 5000" > docker.yaml
kubectl apply -f docker.yaml

export IP=$(ip -f inet addr show eth1 | grep -m 1 -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | head -1) 
echo "${IP} registry registry.local" | sudo tee --append /etc/hosts

echo 'mirrors:
  "registry.local:5000":
    endpoint:
      - "http://registry.local:5000"' | sudo tee /etc/rancher/k3s/registries.yaml

echo '{
    "insecure-registries" : [ "registry.local:5000" ]
}'| sudo tee /etc/docker/daemon.json

echo $IP | sudo tee /usr/master_ip
sudo cp /var/lib/rancher/k3s/server/node-token /usr/master_token
sudo chmod a+r /usr/master_token


SCRIPT_MASTER_NODE


$script_worker = <<-SCRIPT_WORKER_NODE

#create USER user and add it to the k3s-admin group
sudo adduser USER --disabled-password --gecos ""
echo 'USER:PASSWORD' | sudo chpasswd
echo "USER  ALL=(ALL:ALL) ALL" | sudo tee --append /etc/sudoers
sudo su USER
 
export MASTERIP=$(cat /tmp/master_ip) 
export MASTERTOKEN=$(cat /tmp/master_token)
echo "PASSWORD" | sudo -S -v
 
sudo sed -i '/net.ipv4.ip_forward/s/^#//g' /etc/sysctl.conf
 
curl -sfL https://get.k3s.io | K3S_URL=https://$MASTERIP:6443 K3S_TOKEN=$MASTERTOKEN sh -
 
export IP=$(ip -f inet addr show eth1 | grep -m 1 -oE '((1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])\.){3}(1?[0-9][0-9]?|2[0-4][0-9]|25[0-5])' | head -1) 
echo "${IP} registry registry.local" | sudo tee --append /etc/hosts
 
sudo mkdir /etc/rancher/k3s
 
echo 'mirrors:
  "registry.local:5000":
    endpoint:
      - "http://registry.local:5000"' | sudo tee /etc/rancher/k3s/registries.yaml

SCRIPT_WORKER_NODE

Vagrant.configure(2) do |config|

  # Distribution
  config.vm.box = "generic/ubuntu2004" # 20.04 LTS

  # Memory
  config.vm.provider :libvirt do |libvirt|
    libvirt.cpus = 1
    libvirt.memory = 4096
    libvirt.host_device_exclude_prefixes = ['docker', 'macvtap', 'vnet']
  end

  # we don't need to sync folder with host
  #config.vm.synced_folder "../../", "/vagrant", mount_options: ["dmode=775", "fmode=664"]
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # Provisioning

  config.vm.define "master-node" do |master_node|
    master_node.vm.hostname = "master-node"
    master_node.vm.provision "shell", inline: $script_master, privileged: false
    master_node.vm.network :public_network, :dev => "virbr0",:mode => "bridge",:type => "bridge"
    #master_node.vm.network :private_network, :libvirt__network_name => "k3s_libvirt"
  end

  (1..3).each do |i|
    config.vm.define "worker-node-#{i}" do |node|
      node.vm.hostname = "worker-node-#{i}"
      #node.vm.provision "shell", inline: $script_worker, privileged: false
      node.vm.network :public_network,:dev => "virbr0",:mode => "bridge",:type => "bridge"
      node.trigger.after :provision do |trigger|
        trigger.run_remote = {inline: $script_worker}
      end
    end
  end
  #config.vm.define "worker-node-1" do |worker_node_1|
  #  worker_node_1.vm.hostname = "worker-node-1"
  #  #worker_node_1.vm.provision "shell", inline: $script_worker, privileged: false
  #  worker_node_1.vm.network :public_network,:dev => "virbr0",:mode => "bridge",:type => "bridge"
  #  worker_node_1.trigger.after :provision do |trigger|
  #    trigger.run_remote = {inline: $script_worker}
  #  end
  #end
  #config.vm.define "worker-node-2" do |worker_node_2|
  #  worker_node_2.vm.hostname = "worker-node-2"
  #  worker_node_2.vm.provision "shell", inline: $script_worker, privileged: false
  #  worker_node_2.vm.network :public_network,:dev => "virbr1",:mode => "bridge",:type => "bridge"
  #end
  #config.vm.define "worker-node-3" do |worker_node_3|
  #  worker_node_3.vm.hostname = "worker-node-3"
  #  worker_node_3.vm.provision "shell", inline: $script_worker, privileged: false
  #  worker_node_3.vm.network :public_network,:dev => "virbr1",:mode => "bridge",:type => "bridge"
  #end

end
