#!/bin/bash

# convenience script if you don't want to apply all yaml files manually

export JENKINS_USER=$(cat creds.json | jq -r '.jenkinsUser')
export JENKINS_PASSWORD=$(cat creds.json | jq -r '.jenkinsPassword')
export GITHUB_PERSONAL_ACCESS_TOKEN=$(cat creds.json | jq -r '.githubPersonalAccessToken')
export GITHUB_USER_NAME=$(cat creds.json | jq -r '.githubUserName')
export GITHUB_USER_EMAIL=$(cat creds.json | jq -r '.githubUserEmail')
export DT_TENANT_ID=$(cat creds.json | jq -r '.dynatraceTenant')
export DT_ACCOUNTID=$(cat creds.json | jq -r '.dtaccountid')
export NL_WEB_API_KEY=$(cat creds.json | jq -r '.nlwebapikey')
export DT_API_TOKEN=$(cat creds.json | jq -r '.dynatraceApiToken')
export DT_PAAS_TOKEN=$(cat creds.json | jq -r '.dynatracePaaSToken')
export GITHUB_ORGANIZATION=$(cat creds.json | jq -r '.githubOrg')
export DT_TENANT_URL="$DT_TENANT_ID.live.dynatrace.com"


cp ../manifests/k8s-jenkins-deployment.yml ../manifests/k8s-jenkins-deployment_tmp.yml
sed -i 's/GITHUB_USER_EMAIL_PLACEHOLDER/'"$GITHUB_USER_EMAIL"'/' ../manifests/k8s-jenkins-deployment_tmp.yml
sed -i 's/GITHUB_ORGANIZATION_PLACEHOLDER/'"$GITHUB_ORGANIZATION"'/' ../manifests/k8s-jenkins-deployment_tmp.yml
sed -i 's/DOCKER_REGISTRY_IP_PLACEHOLDER/docker-registry.default.svc/' ../manifests/k8s-jenkins-deployment_tmp.yml
sed -i 's/DT_TENANT_URL_PLACEHOLDER/'"$DT_TENANT_URL"'/' ../manifests/k8s-jenkins-deployment_tmp.yml
sed -i 's/DT_API_TOKEN_PLACEHOLDER/'"$DT_API_TOKEN"'/' ../manifests/k8s-jenkins-deployment_tmp.yml

# configure the host path volume plugin
oc create -f ../manifests/oc-scc-hostpath.yml
oc patch scc hostpath -p '{"allowHostDirVolumePlugin": true}'
oc adm policy add-scc-to-group hostpath system:authenticated

oc create -f ../manifests/k8s-namespaces.yml 

oc create -f ../manifests/k8s-jenkins-pvcs.yml 
oc create -f ../manifests/k8s-jenkins-deployment_tmp.yml
oc create -f ../manifests/k8s-jenkins-rbac.yml

rm ../manifests/k8s-jenkins-deployment_tmp.yml

oc project cicd
# create a route for the jenkins service
oc expose svc/jenkins

# store the jenkins route in a variable
export JENKINS_URL=$(oc get route jenkins -o=json | jq -r '.spec.host')

# set up the OpenShift registry
oc new-project sockshop-registry
oc project sockshop-registry
oc create serviceaccount pusher
oc policy add-role-to-user system:image-builder system:serviceaccount:sockshop-registry:pusher


oc create -f ../manifests/oc-imagestreams.yml

oc policy add-role-to-user system:image-puller system:serviceaccount:dev:default -n sockshop-registry
oc policy add-role-to-user system:image-puller system:serviceaccount:staging:default -n sockshop-registry
oc policy add-role-to-user system:image-puller system:serviceaccount:production:default -n sockshop-registry

oc describe sa pusher
export PUSHER_TOKEN=$(oc describe sa pusher -n sockshop-registry | grep -m1 pusher-token | sed -e 's/^[(Mountable secrets:|Tokens:)* \t]*//')
export TOKEN_VALUE=$(oc describe secret $PUSHER_TOKEN -n sockshop-registry | grep token: | sed -e 's/token:[ \t]*//')
echo $TOKEN_VALUE

# deploy the Dynatrace Operator
oc adm new-project dynatrace
oc create -f https://raw.githubusercontent.com/Dynatrace/dynatrace-oneagent-operator/master/deploy/openshift.yaml
sleep 30
oc -n dynatrace create secret generic oneagent --from-literal="apiToken=$DT_API_TOKEN" --from-literal="paasToken=$DT_PAAS_TOKEN"
cp ../manifests/dynatrace/cr.yml ../manifests/dynatrace/cr_tmp.yml
sed -i 's/ENVIRONMENTID/'"$DT_TENANT_ID"'/' ../manifests/dynatrace/cr_tmp.yml
oc create -f ../manifests/dynatrace/cr_tmp.yml
rm ../manifests/dynatrace/cr_tmp.yml

# create the backend services for the sockshop (user-db shipping-queue) - exchange this for ./create-sockshop.sh to deploy the complete application
#./backend-services.sh
./deploy-sockshop.sh

# set up credentials in Jenkins
sleep 150
curl -X POST http://$JENKINS_URL/credentials/store/system/domain/_/createCredentials --user $JENKINS_USER:$JENKINS_PASSWORD \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "registry-creds",
    "username": "user",
    "password": "'$TOKEN_VALUE'",
    "description": "Token used by Jenkins to push to the OpenShift container registry",
    "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}'

curl -X POST http://$JENKINS_URL/credentials/store/system/domain/_/createCredentials --user $JENKINS_USER:$JENKINS_PASSWORD \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "git-credentials-acm",
    "username": "'$GITHUB_USER_NAME'",
    "password": "'$GITHUB_PERSONAL_ACCESS_TOKEN'",
    "description": "Token used by Jenkins to access the GitHub repositories",
    "$class": "com.cloudbees.plugins.credentials.impl.UsernamePasswordCredentialsImpl"
  }
}'

curl -X POST http://$JENKINS_URL/credentials/store/system/domain/_/createCredentials --user $JENKINS_USER:$JENKINS_PASSWORD \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "perfsig-api-token",
    "apiToken": "'$DT_API_TOKEN'",
    "description": "Dynatrace API Token used by the Performance Signature plugin",
    "$class": "de.tsystems.mms.apm.performancesignature.dynatracesaas.model.DynatraceApiTokenImpl"
  }
}'

# set up openshift sync plugin
oc project cicd
oc create serviceaccount jenkins
oc adm policy add-cluster-role-to-user edit system:serviceaccount:cicd:jenkins
export JENKINS_SYNC_TOKEN=$(oc serviceaccounts get-token jenkins -n cicd)

curl -X POST http://$JENKINS_URL/credentials/store/system/domain/_/createCredentials --user $JENKINS_USER:$JENKINS_PASSWORD \
--data-urlencode 'json={
  "": "0",
  "credentials": {
    "scope": "GLOBAL",
    "id": "openshift-sync",
    "secret": "'$JENKINS_SYNC_TOKEN'",
    "description": "Token for the jenkins service account user",
    "$class": "io.fabric8.jenkins.openshiftsync.OpenShiftToken"
  }
}'

cat ../manifests/pipelines/sockshop-pipelines.yml | sed 's~GITHUB_ORG_PLACEHOLDER~'"$GITHUB_ORGANIZATION"'~' >> ../manifests/pipelines/sockshop-pipelines_tmp.yml
oc apply -f ../manifests/pipelines/sockshop-pipelines_tmp.yml
rm ../manifests/pipelines/sockshop-pipelines_tmp.yml

# Install Istio service mesh
./install-istio.sh $DT_TENANT_ID $DT_PAAS_TOKEN
