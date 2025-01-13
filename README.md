# DevSpaces development process

To use DevSpaces to work on this project click on the link below.

BEFORE you click the workspace button, copy the configuration lines below !

[<img src=DevSpaces.png width=50>](https://devspaces.apps.cluster-ktrst.ktrst.sandbox1131.opentlc.com/dashboard/#/load-factory?url=https%3A%2F%2Fraw.githubusercontent.com%2Fmarrober%2Fpacman%2Frefs%2Fheads%2Fmain%2Fdevfile.yaml)

## Configure each devspaces instance

Apply the following in a terminal window for the devspaces instance :

````bash
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global user.email marrober@redhat.com
git config --global user.name marrober
````

# Creation of demonstration assets

## Create argocd projects and applications

cd < clone-location >/pacman

oc apply -k .

## Get image information for dockerfile

````bash
oc project pacman-ci
oc get is/rhel9-nodejs-16 -o jsonpath='{.status.publicDockerImageRepository}''{":latest"}''{"\n"}'
````

Update the dockerfile at pacman/src/dockerfile to the local path to the rhel9-nodejs-16 image.

## Create github access token

Use the command shown below, with an appropriate token :

````bash
oc create secret generic github-access-token --from-literal=token=
````

## Create a secret for access to quay.

````bash
oc apply -f ~/Downloads/marrober-secret.yml
````

## ArgoCD Sync config

Login to the ArgoCD instance and create the role and policy

````bash
argocd login --username admin --password $(oc get secret/argocd-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --insecure --grpc-web $(oc get route/argocd-server -n openshift-gitops -o jsonpath='{.spec.host}')

argocd proj role create pacman pacman-sync --grpc-web
argocd proj role add-policy pacman pacman-sync --action 'sync' --permission allow --object pacman-development --grpc-web
````

### instructions for using a token

// argocd proj role create-token pacman pacman-sync (not required)
// Copy token to the file cd/env/01-dev/argocd-auth-token.yaml

### instructions for using a secret created from the ArgoCD username and password
Create a secret using the following config :

````bash
oc create secret generic -n pacman-ci argocd-env-secret --from-literal=ARGOCD_PASSWORD=$(oc get secret/argocd-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --from-literal=ARGOCD_USERNAME=admin
````

### get the ArgoCD URL


````bash
oc get route/argocd-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}'
````

Copy the Argocd URL (Without  https://) and paste it into the file cd/env/config/argocd-platform-cm.yaml

## Create a secret for access to the ACS CI/CD process

Generate the CI/CD token inside ACS. Go to Platform configurations -> Integrations -> Authentication tokens.
Generate a new CI/CD Scoped token.

Execute the following command :

oc create secret generic acs-secret \
--from-literal=acs_api_token=<token from above step> \
--from-literal=acs_central_endpoint=$(oc get route/central -n stackrox -o jsonpath='{.spec.host}{":443"}')

## ACS read the Openshift Image Registry

Patch the cluster to enable image streams for external access.
Get the route and a user token for access to the image streams. 

````bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge

oc get route default-route -n openshift-image-registry --template='{{ .spec.host }}'
````

## Get SA secret for ACS access to registry

oc get secret/image-pusher-dockercfg-sjnjk -n pacman-ci -o 'go-template={{index .data ".dockercfg"}}' | base64 -d | jq .  

Take the auth section from the item with index : image-registry.openshift-image-registry.svc:5000

echo -n "<auth section>" | base64 -d

Extract the token and use on the password field below.

In ACS go to Platform configurations -> Integrations -> Image integration -> Generic Docker Registry and press the ‘Create integration’ button.
Fill in the details as :
	Integration name : OCP Registry
	Endpoint : https://image-registry.openshift-image-registry.svc:5000
	Username : admin
	Password : <token from prior command>
	Check the option : Disable TLS certificate validation (insecure)
Test the integration and save if successful.

## For signing commits to GitHub

Run the script content at : Note : Copy and paste the content into a command window. Do not run as a shell script.

````bash
image-git-signing-setup/local-git-signing-setup.txt
````

## Test the pipeline execution

````bash
oc create -f ci-application/pipelinerun.yaml 
````

## Create a webhook in Github

Ensure a webhook exists here : https://github.com/marrober/pacman/settings/hooks pointing to the trigger listener route in the pacman-ci namespace.

## Test the triggered execution of the pipeline

Make a change to the application source code at : src/public/pacman-canvas.js line 292. Change the colour to either Blue, Green or Red and commit the change to the github repositry and push to the origin.

# DevSpaces configuration

Configure a global oauth connection to guthub using the information here : https://eclipse.dev/che/docs/stable/administration-guide/configuring-oauth-2-for-github/

Github app created in marrober Github location on 8th January with the credentials in Notes document.

Create the secret on the OCP cluster as :

````bash
kind: Secret
apiVersion: v1
metadata:
  name: github-oauth-config
  namespace: openshift-devspaces
  labels:
    app.kubernetes.io/part-of: che.eclipse.org
    app.kubernetes.io/component: oauth-scm-configuration
  annotations:
    che.eclipse.org/oauth-scm-server: github
    che.eclipse.org/scm-server-endpoint: https://github.com
    che.eclipse.org/scm-github-disable-subdomain-isolation: 'true'
type: Opaque
stringData:
  id: <from notes>
  secret: <from notes>
````

Do this before creating any DevSpaces. 

## Configure each devspaces instance

Apply the following in a terminal window for the devspaces instance :

````bash
git config --global commit.gpgsign false
git config --global tag.gpgsign false
git config --global user.email marrober@redhat.com
git config --global user.name marrober
````


