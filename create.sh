#export VAGRANT_EXPERIMENTAL="typed_triggers"
#cleanup
rm master_ip master_token

vagrant up master-node
vagrant scp master-node:/usr/master_ip .
vagrant scp master-node:/usr/master_token .
for (( i = 1; i < 4; i++ )); do
	vagrant up worker-node-$i
	vagrant scp master_token worker-node-$i:/tmp/
	vagrant scp master_ip worker-node-$i:/tmp/
	vagrant provision worker-node-$i
done