#!/bin/bash
#Kubernetes Backup export config to json file

environment="${1:-pre}"
environmentContext="${1:-pre}"
#We use same context for dev and pre
if [ "$environmentContext" == "int" ]; then
    environmentContext=pre
fi

today=$(date +%Y-%m-%d.%H:%M:%S)
gitRootFolder=/srv/tol-devops-configuration/$environment

#rm -Rf $gitRootFolder/*

export KUBECONFIG=$KUBECONFIG:$HOME/.kube/config
/var/lib/rundeck/ansible-playbooks/k8s-backups/kubectl config use-context kubernetes-admin-$environmentContext@kubernetes

rm $gitRootFolder/k8s-$environment-cluster.json
for ns in $(kubectl get ns --no-headers | cut -d " " -f1); do
    #if { [ "$ns" != "kube-system" ]; }; then
    if { [[ "$ns" == *"-$environment"* ]]; }; then
        if [ ! -d $gitRootFolder/$ns ]; then
            mkdir $gitRootFolder/$ns
        fi
        #Deployments
        /var/lib/rundeck/ansible-playbooks/k8s-backups/kubectl --namespace="${ns}" get --export -o=json deployments |
            jq '.items[] |
    select(.type!="kubernetes.io/service-account-token") |
    del(
        .spec.clusterIP,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .status,
        .spec.template.spec.securityContext,
        .spec.template.spec.dnsPolicy,
        .spec.template.spec.terminationGracePeriodSeconds,
        .spec.template.spec.restartPolicy
    )' >"$gitRootFolder/$ns/cluster-deployments.json"
        #Services
        /var/lib/rundeck/ansible-playbooks/k8s-backups/kubectl --namespace="${ns}" get --export -o=json services |
            jq '.items[] |
    select(.type!="kubernetes.io/service-account-token") |
    del(
        .spec.clusterIP,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .status,
        .spec.template.spec.securityContext,
        .spec.template.spec.dnsPolicy,
        .spec.template.spec.terminationGracePeriodSeconds,
        .spec.template.spec.restartPolicy
    )' >"$gitRootFolder/$ns/cluster-services.json"
        #Ingress config
        /var/lib/rundeck/ansible-playbooks/k8s-backups/kubectl --namespace="${ns}" get --export -o=json ingress |
            jq '.items[] |
    select(.type!="kubernetes.io/service-account-token") |
    del(
        .spec.clusterIP,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .status,
        .spec.template.spec.securityContext,
        .spec.template.spec.dnsPolicy,
        .spec.template.spec.terminationGracePeriodSeconds,
        .spec.template.spec.restartPolicy
    )' >"$gitRootFolder/$ns/cluster-ingress.json"

        #All namespace info
        /var/lib/rundeck/ansible-playbooks/k8s-backups/kubectl --namespace="${ns}" get --export -o=json svc,rc,secrets,ds,cm,deploy,hpa,pv,pvc,quota,limits,storageclass,ingress |
            jq '.items[] |
    select(.type!="kubernetes.io/service-account-token") |
    del(
        .spec.clusterIP,
        .metadata.uid,
        .metadata.selfLink,
        .metadata.resourceVersion,
        .metadata.creationTimestamp,
        .metadata.generation,
        .status,
        .spec.template.spec.securityContext,
        .spec.template.spec.dnsPolicy,
        .spec.template.spec.terminationGracePeriodSeconds,
        .spec.template.spec.restartPolicy
    )' >"$gitRootFolder/$ns/cluster-complete.json"
        # All clustr info
        cat $gitRootFolder/$ns/cluster-complete.json >>$gitRootFolder/k8s-$environment-cluster.json
    fi
done
