# Creation of demonstration assets

## Patch registry routes
Patch the cluster to enable image streams for external access.

````bash
oc patch configs.imageregistry.operator.openshift.io/cluster --patch '{"spec":{"defaultRoute":true}}' --type=merge
````

## Create argocd projects and applications

````bash
cd < clone-location >/pacman
oc apply -k .
````

## Get image information for dockerfile

````bash
oc project pacman-ci
oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}''{":latest"}''{"\n"}'
````

Update the dockerfile in src/dockerfile with the command : 

````bash
echo -e "FROM $(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}''{":latest"}''{"\n"}')\nUSER 0\nCOPY . /opt/app-root/src/\nRUN chmod a+w /var/log\nUSER 1001\nCMD [\"npm\", \"start\"]" > src/dockerfile
````

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
argocd login --username admin --password $(oc get secret/openshift-gitops-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --insecure --grpc-web $(oc get route/openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}')
````
OR

````bash
argocd login --username admin --password $(oc get secret/argocd-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --insecure --grpc-web $(oc get route/argocd-server -n openshift-gitops -o jsonpath='{.spec.host}')
````

THEN

````bash
argocd proj role create pacman pacman-sync --grpc-web
argocd proj role add-policy pacman pacman-sync --action 'sync' --permission allow --object pacman-development --grpc-web
````

### instructions for using a secret created from the ArgoCD username and password
Create a secret using the following config :

````bash
oc create secret generic -n pacman-ci argocd-env-secret --from-literal=ARGOCD_PASSWORD=$(oc get secret/openshift-gitops-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --from-literal=ARGOCD_USERNAME=admin
````

OR

````bash
 oc create secret generic -n pacman-ci argocd-env-secret --from-literal=ARGOCD_PASSWORD=$(oc get secret/argocd-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d) --from-literal=ARGOCD_USERNAME=admin
 ````

### get the ArgoCD URL


````bash
oc get route/openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}'
````

OR

````bash
oc get route/argocd-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}'
````


Copy the Argocd URL (Without  https://) and paste it into the file cd/env/config/argocd-platform-cm.yaml using the command : 

````bash
echo -e "apiVersion: v1\nkind: ConfigMap\nmetadata:\n  name: argocd-env-configmap\n  namespace: pacman-ci\ndata:\n  ARGOCD_SERVER: $(oc get route/openshift-gitops-server -n openshift-gitops -o jsonpath='{.spec.host}{"\n"}')" > cd/env/config/argocd-platform-cm.yaml
````

## Create a secret for access to the ACS CI/CD process

Generate the CI/CD token inside ACS. Go to Platform configurations -> Integrations -> Authentication tokens.
Generate a new CI/CD Scoped token.

Execute the following command :

````bash
oc create secret generic acs-secret \
--from-literal=acs_api_token=<token from above step> \
--from-literal=acs_central_endpoint=$(oc get route/central -n stackrox -o jsonpath='{.spec.host}{":443"}')
````

# ACS read the Openshift Image Registry

````bash
oc get sa/image-pusher -o yaml | grep image-pusher-dockercfg
````

Create a new role in the openshift-pipelines namespace to grant permission to read secrets.

````bash
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: view-secret
  namespace: openshift-pipelines
rules:
- apiGroups:
  - ""
  resources:
  - secrets
  verbs:
  - get
  - watch
  - list
````

Create a role binding to the pipeline SA in the pacman-ci namespace.

````bash
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pacman-ci-sa-pipeline-view-secrets-ocp-pipelines
  namespace: openshift-pipelines
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: view-secret
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: pacman-ci
````

### Create a long lived token

To create a token that will not time out quickly use the command below. This will create a token that will last 625 days.

````bash
oc create token pipeine --duration=15000h --bound-object-kind Secret --bound-object-name pipeine-dockercfg-<whatever>
````

Take the password section from the item with index : default-route-openshift-image-registry.apps.cluster-.....

base64 decode the output and use the token below.

Get the default route : 

````bash
 oc get is/nodejs -o jsonpath='{"https://"}''{.status.publicDockerImageRepository}' | cut -d "/" -f 1-3
 ````

In ACS go to Platform configurations -> Integrations -> Image integration -> Generic Docker Registry and press the ‘Create integration’ button.
Fill in the details as :
	Integration name : OCP Registry
	Endpoint : https://default-route-openshift-image-registry.apps.cluster-.....
	Username : admin
	Password : token from above
	Check the option : Disable TLS certificate validation (insecure)
Test the integration and save if successful.

## For signing container images

To enable tekton chains to sign container images and commit signatures and attestations to quay.io create a secret that provides the credentials for a quay.io robot account.

````bash
oc create secret generic quay-chains-creds --from-file=.dockerconfigjson=<(oc create secret docker-registry temp-quay-secret \
    --docker-server=quay.io \
    --docker-username='marrober+api_access' \
    --docker-password='<quay-robot-account-password>' \
    --dry-run=client -o jsonpath='{.data.\.dockerconfigjson}' | base64 -d) --type=kubernetes.io/dockerconfigjson -n pacman-ci
````

Then patch the pipeline service account to reference the above secret

````bash
oc patch serviceaccount pipeline   -n pacman-ci   --type='json'   -p='[{"op": "add", "path": "/secrets/-", "value": {"name": "quay-chains-creds"}}]'
````

Update the TektonInstallerSet custom resource definition :

````bash
apiVersion: operator.tekton.dev/v1alpha1
kind: TektonInstallerSet
metadata:
  name: chain-config-<something>>
spec:
  manifests:
    - apiVersion: v1
      data:
        artifacts.taskrun.storage: oci
        artifacts.pipelinerun.storage: oci
        artifacts.pipelinerun.format: in-toto
        transparency.enabled: 'true'
        artifacts.taskrun.format: slsa/v1
        performance: |
          disable-ha: false
        artifacts.oci.storage: oci
        transparency.url: 'http://rekor-server.trusted-artifact-signer.svc.cluster.local'
        artifacts.oci.format: simplesigning
        artifacts.oci.signer: x509
      kind: ConfigMap
````

To suspend signing of container images in Tekton add the field :

````bash
      data:
        artifacts.oci.signer: "none" 
````

Check the status of the Tekton signing configuration :

''''bash
oc get configmap/chains-config -n openshift-pipelines -o jsonpath='{.data['\''transparency\.enabled'\'']}' ; echo ""\n
oc get configmap/chains-config -n openshift-pipelines -o jsonpath='{.data['\''artifacts\.oci\.signer'\'']}' ; echo ""\n
oc get configmap/chains-config -n openshift-pipelines -o jsonpath='{.data['\''artifacts\.pipelinerun\.format'\'']}' ; echo ""\n
oc get configmap/chains-config -n openshift-pipelines -o jsonpath='{.data['\''transparency\.url'\'']}' ; echo ""\n
 ''''

## Verification

Verifying the image signature and getting the attestation information

### Verify the signature

````bash
cosign-2 verify --key <cosign-public-key> <container-image>
````

The above should report :

````bash
Verification for <container-image> --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key

[{"critical":{"identity":{"docker-reference":"<image-name>"},"image":{"docker-manifest-digest":"sha256:108b44d3d8ba35b9ae20f17f77a79b1c01b7c6d5f84589c1049a611fafeb081b"},"type":"cosign container image signature"},"optional":null}]
````

### To extract the attestation

````bash
cosign-2 verify-attestation --key <cosign-public-key> --type https://slsa.dev/provenance/v0.2 <container-image> | jq -s -r '.[0].payload' | base64 -d
````

The above command results in a test block similar to :

````bash
Verification for quay.io/marrober/pacman:fjbpj-02f7c --
The following checks were performed on each of these signatures:
  - The cosign claims were validated
  - Existence of the claims in the transparency log was verified offline
  - The signatures were verified against the specified public key
{"_type":"https://in-toto.io/Statement/v0.1","subject":[{"name":"quay.io/marrober/pacman","digest":{"sha256":"108b44d3d8ba35b9ae20f17f77a79b1c01b7c6d5f84589c1049a611fafeb081b"}}],"predicateType":"https://slsa.dev/provenance/v0.2","predicate":{"buildConfig":{"steps":[{"annotations":null,"
````

The text information is send to std error or some other stream because the json block can be simply piped to jq to present the information better or to extract specific fields of interest.

The second payload section includes more extensive information on the build process. The above command repeated with the json query '.[1].payload' results in a more extensive block of text that contains a breakdown of the build process.


## For signing commits to GitHub

Run the script content at : Note : Copy and paste the content into a command window. Do not run as a shell script.

````bash
image-git-signing-setup/local-git-signing-setup.txt
````
## Update image paths in various files

Get the path to the image in the image stream using the command :

````bash
oc get is/nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1
````

Get the old default route from the file cd/env/01-dev/deployment.yaml

Update this value in :

cd/env/01-dev/deployment.yaml
cd/env/01-dev/kustomization.yaml
ci-application/pipelinerun.yaml - IMAGE_NAME property
ci-application/triggers/triggerTemplate.yaml - IMAGE_NAME property

````bash
echo -e "cd cd/env/01-dev\nsed -i 's/$(cat cd/env/01-dev/deployment.yaml | grep "image: default" | cut -d ":" -f 2 | tr -d " " | cut -d "/" -f 1)/$(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1)/' deployment.yaml\ncd ../../.."    
````

````bash
echo -e "cd cd/env/01-dev\nsed -i 's/$(cat cd/env/01-dev/kustomization.yaml | grep "name: default" | cut -d ":" -f 2 | tr -d " " | cut -d "/" -f 1)/$(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1)/' kustomization.yaml\ncd ../../.."
````

````bash
echo -e "cd ci-application\nsed -i 's/$(cat ci-application/pipelinerun.yaml | grep "value: default" | cut -d ":" -f 2 | tr -d " " | cut -d "/" -f 1)/$(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1)/' pipelinerun.yaml\ncd .."
 ````

 ````bash
 echo -e "cd ci-application/triggers\nsed -i 's/$(cat ci-application/triggers/triggerTemplate.yaml | grep "value: default" | cut -d ":" -f 2 | tr -d " " | cut -d "/" -f 1)/$(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1)/' triggerTemplate.yaml\ncd ../.."
 ````

````bash
 echo -e "cd ci-application\nsed -i 's/$(cat ci-application/pipelinerun.yaml | grep "keycloak" | cut -d ":" -f 3 | cut -d "/" -f 3 | cut -d "." -f 2-6)/$(oc get is/rhel9-nodejs -o jsonpath='{.status.publicDockerImageRepository}' | cut -d "/" -f 1 | cut -d "." -f 2-7)/' pipelinerun.yaml\ncd .."
 ````


Checkin the changes to the Git repo.

## Get the ArgoCD credentials and address :

````bash
oc get secret/argocd-cluster  -n openshift-gitops -o jsonpath='{.data.admin\.password}' | base64 -d 
echo ""
oc get route/argocd-server  -n openshift-gitops -o jsonpath='{"https://"}''{.spec.host}'
echo ""
````

## Test the pipeline execution

````bash
oc create -f ci-application/pipelinerun.yaml 
````

## Create a webhook in Github

Get the path for the pipeline trigger from the command :

````bash
oc get route/pacman-ci-listener-el -o jsonpath='{"http://"}{.spec.host}'
echo ""
````

Ensure a webhook exists here : https://github.com/marrober/pacman/settings/hooks pointing to the trigger listener route in the pacman-ci namespace. 

## Test the triggered execution of the pipeline

Make a change to the application source code at : src/public/pacman-canvas.js line 292. Change the colour to either Blue, Green or Red and commit the change to the github repositry and push to the origin.

# DevSpaces configuration

Configure a global oauth connection to github using the information here : https://eclipse.dev/che/docs/stable/administration-guide/configuring-oauth-2-for-github/

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
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global user.email marrober@redhat.com
git config --global user.name marrober
git config --global gitsign.fulcio $(oc get fulcio -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
git config --global gitsign.issuer $(oc get route keycloak -n keycloak-system -o jsonpath='{"https://"}{.spec.host}{"/auth/realms/openshift"}')
git config --global gitsign.rekor $(oc get rekor -n trusted-artifact-signer -o jsonpath='{.items[0].status.url}')
git config --local commit.gpgsign true
git config --global gitsign.clientid trusted-artifact-signer

export SIGSTORE_TUF_ROOT="$HOME/.sigstore/root"
export SIGSTORE_REKOR_URL=$(oc get rekor -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
export SIGSTORE_FULCIO_URL=$(oc get fulcio -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
export TUF_URL=$(oc get tuf -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
````

To switch off git signing afterwards use the command 

`````bash
git config --local commit.gpgsign false
`````


Get the current git environment information with :

`````bash
git config -l | cat
`````

## Vulnerability demonstrations


## Clean packages spec :

  "dependencies": {
    "body-parser": "^2.2.2",
    "express": "^5.2.1",
    "mongodb": "^2.2.4",
    "_comment": "mongodb clean version is 7.2.0, and for an example with vulnerabilities use 2.2.24",
    "pug": "^3.0.4"
  },
  "devDependencies": {
    "nodemon": "^3.1.14"

## Old packages spec :

  "dependencies": {
    "body-parser": "^1.20.3",
    "express": "^4.14.1",
    "jade": "^1.11.0",
    "mongodb": "^2.2.24"
  },
  "devDependencies": {
    "nodemon": "^1.11.0"


## Combinations of images and packages

### Test 1
registry.access.redhat.com/hi/nodejs/latest
express - version 3.19.1

The above generates a small number of violations in the base (typically 1) and around 14 in the application layer.
The base image vulnerability doesn't currently show in the ACS view.

example : pacman-pr-qgr6b

### Test 2
registry.access.redhat.com/hi/nodejs/latest
express - version 4.21.2

The above generates violations only in the base (typically 1).
There are no vulnerabilities in the application layer.

example : pacman-pr-jtctq

### Test 3
default-route-openshift-image-registry.apps.ocp4.mr-openshift.co.uk/pacman-ci/nodejs:nodejs-22-9.8-178
express - version 4.21.2

### Older versions

From last week - this seemed to work
default-route-openshift-image-registry.apps.ocp4.mr-openshift.co.uk/pacman-ci:1-1778142166
comes from registry.redhat.io/rhel9/nodejs-20:1-1778142166
express - version 3.19.1

example : pacman-pr-dlpgni
