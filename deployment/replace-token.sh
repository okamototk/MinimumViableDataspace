#!/bin/sh

sleep 60
NS=mvd
TOKEN=$(kubectl  exec   -it -nmvd consumer-vault-0 -- cat /vault/data/seal-keys |grep Root |awk '{print $4}')
echo $TOKEN
for i in consumer-controlplane-config consumer-dataplane-config consumer-identityhub-ih-config
do
	echo $i
	kubectl get cm -n $NS -oyaml $i > work.yaml
        sed "s/  EDC_VAULT_HASHICORP_TOKEN\:.*/  EDC_VAULT_HASHICORP_TOKEN: $TOKEN/" < work.yaml > modified.yaml
	kubectl apply -f modified.yaml
done

TOKEN=$(kubectl  exec   -it -nmvd provider-vault-0 -- cat /vault/data/seal-keys |grep Root |awk '{print $4}')
echo $TOKEN
for i in provider-catalog-server-connector-config provider-manufacturing-controlplane-config provider-manufacturing-dataplane-config provider-qna-controlplane-config provider-qna-dataplane-config provider-identityhub-ih-config
do 
	echo $i
        kubectl get cm -n $NS -oyaml $i > work.yaml
        sed "s/  EDC_VAULT_HASHICORP_TOKEN\:.*/  EDC_VAULT_HASHICORP_TOKEN: $TOKEN/" < work.yaml > modified.yaml
        kubectl apply -f modified.yaml
done


rm work.yaml modified.yaml

## Restart Pod
for i in $(kubectl get deploy -nmvd |awk 'NR>1{print $1}')
do
	kubectl rollout restart deployment $i -n$NS
done


