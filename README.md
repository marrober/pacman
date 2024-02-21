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

## Create a secret for access to the ACS CI/CD process

Generate the CI/CD token inside ACS. Go to Platform configurations -> Integrations -> Authentication tokens.
Generate a new CI/CD Scoped token.
Execute the following command :

oc create secret generic acs-secret \
--from-literal=acs_api_token=<token from above step> \
--from-literal=acs_central_endpoint=<url-for-rhacs-server>:443

## ACS read the Openshift Image Registry

Get the secret name and token within the secret

````bash
oc get secret/$(oc get sa/builder -o jsonpath='{.secrets[0].name}') -o jsonpath='{.metadata.annotations}' | jq '."openshift.io/token-secret.value"' 
````

Extract the field : openshift.io/token-secret.value into the copy-paste buffer.

In ACS go to Platform configurations -> Integrations -> Image integration -> Generic Docker Registry and press the ‘Create integration’ button.
Fill in the details as :
	Integration name : OCP Registry
	Endpoint : https://image-registry.openshift-image-registry.svc:5000
	Username : serviceaccount
	Password : <as copied from the secret previously>
	Check the option : Disable TLS certificate validation (insecure)
Test the integration and save if successful.

## Test the pipeline execution

````bash
oc create -f ci-application/pipelinerun.yaml 
````

## Create a webhook in Github

Ensure a webhook exists here : https://github.com/marrober/pacman/settings/hooks pointing to the SMEE url tha is in teh smee deployment yaml file. Ensure that the content type is set to application/json.

## Test the triggered execution of the pipeline

Make a change to the application source code at : src/public/pacman-canvas.js line 292. Change the colour to either Blue, Green or Red and commit the change to the github repositry and push to the origin.





