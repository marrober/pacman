# Creation of the assets

## Create argocd projects and applications

cd /Users/mroberts/data/git-repos/pacman

oc apply -k .

## SMEE configuration for demolab

If using demolab and also using triggers from the github commits then the route in the smee deployment may need to change. Check the line below to see if it needs to be updated in the file ci-application/smee/deployment.yaml

````bash
"http://pacman-ci-listener-el-pacman-ci.apps.conroe.demolab.local"
````
## Pull images to local image streams

````bash
oc project pacman-ci
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
oc import-image ubi --from=registry.access.redhat.com/ubi8/ubi:latest --confirm
oc import-image gosmee --from=quay.io/marrober/gosmee:latest --confirm
oc import-image buildah --from=registry.redhat.io/rhel8/buildah:latest --confirm
oc import-image terminal --from=quay.io/marrober/devex-terminal-4:full-terminal-1.5 --confirm
oc import-image nodejs-16 --from=registry.redhat.io/rhel9/nodejs-16 --confirm
````

## Create github access token

Use the command shown below, with an appropriate token :

````bash
oc create secret generic github-access-token --from-literal=token=
````

## Test the pipeline execution

````bash
oc create -f ci-application/pipelinerun.yaml 
````

## Test the triggered execution of the pipeline



