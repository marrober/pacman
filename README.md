# Creation of the assets

## Create argocd projects and applications

cd /Users/mroberts/data/git-repos/pacman

oc apply -k .

## SMEE configuration for demolab

If using demolab and also using triggers from the github commits then the route in the smee deployment may need to change. Check the line below to see if it needs to be updated in the file ci-application/smee/deployment.yaml

````bash
"http://pacman-ci-listener-el-pacman-ci.apps.conroe.demolab.local"
````

