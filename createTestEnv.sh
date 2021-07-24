#!/bin/bash

helpFunction() {
    echo "Script that creates a temporary environment in a dev-test cluster namespace from a copy of the production cluster"
    echo ""
    echo "REQUIREMENTS: install CLIs:"
    echo "1. 'helm v3' (https://get.helm.sh/helm-v3.2.3-linux-amd64.tar.gz)"
    echo "2. 'kubectl' (https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux)"
    echo ""
    echo "IMPORTANT:"
    echo "1. You must have created the namespace in a dev-test rancher cluster project. Ex: env-test"
    echo "2. Add the Charts repository locally"
    echo "            helm repo add harbor https://harbor.app.sof.intra/chartrepo --username XXXXXX --password XXXXXX"
    echo ""
    echo "Use: $0 -n namespace -p /path/to/kubeconfig  -t  /path/to/kubeconfig -r repositorio -f false "
    echo -e "\t-n Namespace to be created"
    echo -e "\t-p kubeconfig file path of the production environment. Download it from Rancher."
    echo -e "\t-t kubeconfig file path of the dev-test environment. Download it from Rancher."
    echo -e "\t-r Name of repository locally will be created  (Ex: harbor)"
    echo -e "\t-f (Optional) true/false. Forces the deletion of all objects in the namespace and the creation of a new one.
                            Or by default, only the service version update will be done through the 'helm update'"
    exit 1 # Exit script after printing help
}

while getopts "n:p:t:r:f:" opt; do
    case "$opt" in
    n) namespace="$OPTARG" ;;
    p) kubeconfig_prod="$OPTARG" ;;
    t) kubeconfig_devtest="$OPTARG" ;;
    r) repo="$OPTARG" ;;
    f) force="true" ;;
    ?) helpFunction ;; # Print helpFunction in case parameter is non-existent
    esac
done

# Print helpFunction in case parameters are empty
if [ -z "$namespace" ] || [ -z "$kubeconfig_prod" ] || [ -z "$kubeconfig_devtest" ] || [ -z "$repo" ]; then
    echo "ERROR: Some parameters are empty!!"
    echo ""
    helpFunction
fi

# Check if the namespace really exists
kubectl --kubeconfig=$kubeconfig_devtest get ns $namespace &>/dev/null
if [ $? -eq 1 ]; then
    echo "Namespace $namespace does not exist. Please create/verify !"
    exit 1
fi

if [ "$force" == "true" ]; then
    echo "Deleting objects from namespace $namespace"
    kubectl delete deploy,ds,pods,sa,services,ingress,cm,secrets --all --kubeconfig=$kubeconfig_devtest -n $namespace &>/dev/null
fi

#export staging configmaps and import into test environment
if [ "$force" == "true" ]; then
    for n in $(kubectl --kubeconfig=$kubeconfig_prod get configmap -n staging -o custom-columns=:metadata.name --no-headers); do
        echo "\n .... Installing staging configmap $n in namespace $namespace"
        kubectl --kubeconfig=$kubeconfig_prod get configmap $n -n staging --export -o yaml | kubectl --kubeconfig=$kubeconfig_devtest apply --namespace=$namespace -f- &>/dev/null
    done
fi

#export staging secrets and import into test environment
if [ "$force" == "true" ]; then
    for n in $(kubectl --kubeconfig=$kubeconfig_prod get secrets -n staging --field-selector=type!=kubernetes.io/service-account-token -o custom-columns=:metadata.name --no-headers); do
        echo "\n ... Installing the staging secrets $n into the namespace $namespace"
        kubectl --kubeconfig=$kubeconfig_prod get secret $n -n staging --export -o yaml | kubectl --kubeconfig=$kubeconfig_devtest apply --namespace=$namespace -f- &>/dev/null
    done
fi

#Install all production application charts into the new test namespace
helm repo update &>/dev/null

for n in $(kubectl --kubeconfig=$kubeconfig_prod get deploy -n production -o custom-columns=:metadata.name --no-headers); do
    echo "\n ... Installing chart $n into namespace $namespace"
    helm upgrade --kubeconfig=$kubeconfig_devtest --install $n $repo/siop/$n --namespace=$namespace --set ingress.host="$namespace.test.app.sof.intra" # &> /dev/null
    echo "Ingress URL set to $namespace.test.app.sof.intra"
done
