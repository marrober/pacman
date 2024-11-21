keycloak=$(oc get route keycloak -n rhsso | tail -n 1 | awk '{print $2}')
issuer=https://$(oc get route keycloak -n rhsso | tail -n 1 | awk '{print $2}')/auth/realms/openshift
rekor=$(oc get rekor -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)

git config --global user.email user1@demo.redhat.com
git config --global user.name user1
git config --global commit.gpgsign true
git config --global tag.gpgsign true
git config --global gpg.x509.program gitsign
git config --global gpg.format x509
git config --global gitsign.fulcio $keycloak
git config --global gitsign.issuer $issuer
git config --global gitsign.rekor $rekor
git config --global gitsign.clientid trusted-artifact-signer