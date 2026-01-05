#!/bin/bash
arg=${1:-"INSTALL"}

NAMESPACE="superset"

prerequisites(){
    helm repo add superset https://apache.github.io/superset  && helm repo update
    helm search repo superset
}
install(){
    printf "\n ----------------------------------------------------------------  "
    printf "\n Installing Apache Superset on K8S ... "
    printf "\n - K8S Installation info: https://superset.apache.org/docs/installation/kubernetes  "
    printf "\n - Apache Superset: OCI dependencies used in the Chart:https://hub.docker.com/r/bitnamicharts/ \n"
    awk '/^dependencies:/{in_deps=1; next} in_deps && /^  - name:/{if(name!=""){printf "   - name: %s, version: %s, OCI-image: https://hub.docker.com/r/bitnamicharts/%s/tags?name=%s\n", name, (version=="" ? "(not specified)" : version), name, version} name=$3; gsub(/#.*/,"",name); gsub(/"/,"",name); gsub(/^[[:space:]]+|[[:space:]]+$/,"",name); version=""; next} in_deps && /^[[:space:]]+version:/ && !/^[[:space:]]*#/{version=$2; gsub(/#.*/,"",version); gsub(/"/,"",version); gsub(/^[[:space:]]+|[[:space:]]+$/,"",version); next} in_deps && /^[a-zA-Z]/{if(name!=""){printf "   - name: %s, version: %s, OCI-image: https://hub.docker.com/r/bitnamicharts/%s/tags?name=%s\n", name, (version=="" ? "(not specified)" : version), name, version; name=""; version=""} in_deps=0} END{if(in_deps && name!=""){printf "   - name: %s, version: %s, OCI-image: https://hub.docker.com/r/bitnamicharts/%s/tags?name=%s\n", name, (version=="" ? "(not specified)" : version), name, version}}' Chart.yaml
    printf "\n ----------------------------------------------------------------  "
    helm upgrade --install ${NAMESPACE} --values my-values.yaml ${NAMESPACE}/${NAMESPACE} --namespace ${NAMESPACE} --create-namespace
}
serviceInfo(){
    printf "\n ----------------------------------------------------------------  "
    printf "\n Service Information: \n"
    printf "\n ----------------------------------------------------------------  \n"

    kubectl get pv
    printf "\n" 
    kubectl get pvc,endpoints,pods,svc,rs,statefulset,deploy,ingress -n ${NAMESPACE} 
    printf "\n"
}
tail-logs() {
    printf "\n ----------------------------------------------------------------  "
    printf "\n TAIL LOGS: \n"
    printf "\n ----------------------------------------------------------------  \n"


}
dbportForward(){
    printf "\n ----------------------------------------------------------------  "
    printf "\n Forwarding PostgreSQL port to localhost:5432 \n"
    printf "\n ----------------------------------------------------------------  \n"

    export DB_NODE_PORT=$(kubectl get svc superset-postgresql -n ${NAMESPACE}  -o jsonpath='{.spec.ports[0].nodePort}')
    printf "\n\nDatabase Port: ${NODE_PORT_HTTP}   JDBC DB URI: jdbc:postgresql://localhost:${DB_NODE_PORT}/artifactory  \n"
    export DB_UPASSWORD=$(kubectl get secrets artifactory-postgresql -n ${NAMESPACE} -o jsonpath='{.data.postgresql-password}' | base64 --decode)
    printf "kubectl exec -it pods/artifactory-postgresql-0 -n artifactory -- psql -d ${NAMESPACE} -U artifactory \n"
    printf "DB Defaults; DB: artifactory   username: artifactory    password: ${DB_UPASSWORD} \n\n"


    kubectl port-forward svc/${NAMESPACE}-postgresql 5432:5432 -n ${NAMESPACE}

}


delete(){
    printf "\n ----------------------------------------------------------------  "
    printf "\n ------------ CLEANING the Apache Superset on K8S ------------  "
    printf "\n ----------------------------------------------------------------  \n"
    helm uninstall ${NAMESPACE} && sleep 90 && kubectl delete pvc -l app=superset
    kubectl delete ns ${NAMESPACE} --force=true --ignore-not-found=true
    printf "\n CLEANING: COMPLETE at $(date +"%Y-%m-%d %H:%M:%S") \n"
}

# -z option with $1, if the first argument is NULL. Set to default
if  [[ -z "$1" ]] ; then # check for null
    echo "User action is NULL, setting to default INSTALL"
    arg='INSTALL'
fi

# -n string - True if the string length is non-zero.
if [[ -n $arg ]] ; then
    arg_len=${#arg}
    # uppercase the argument
    arg=$(echo ${arg} | tr [a-z] [A-Z] | xargs)
    echo "User Action: ${arg}, and arg length: ${arg_len}"
    
    if [[ "INSTALL" == "${arg}" ]] ; then   # Download & install 
        install
        sleep 5
        serviceInfo
    elif [[ "DELETE" == "${arg}" ]] ; then   # delete 
        delete
    elif [[ "INFO" == "${arg}" ]] ; then   # Info 
        serviceInfo
    elif [[ "PRESTEP" == "${arg}" ]] ; then   # Info 
        prerequisites
    fi
fi

printf "\n ----------------------------------------------------------------  "

printf "\n***** [END] TS: $(date +"%Y-%m-%d %H:%M:%S") \n\n"