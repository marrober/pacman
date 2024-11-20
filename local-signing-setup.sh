
echo "Dont run this as a shell script. Copy and paste to the current command line window"

export TUF_URL=$(oc get tuf -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
export OIDC_ISSUER_URL=https://$(oc get route keycloak -n rhsso | tail -n 1 | awk '{print $2}')/auth/realms/openshift
export COSIGN_FULCIO_URL=$(oc get fulcio -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
export COSIGN_REKOR_URL=$(oc get rekor -o jsonpath='{.items[0].status.url}' -n trusted-artifact-signer)
export COSIGN_MIRROR=$TUF_URL
export COSIGN_ROOT=$TUF_URL/root.json
export COSIGN_OIDC_CLIENT_ID="trusted-artifact-signer"
export COSIGN_OIDC_ISSUER=$OIDC_ISSUER_URL
export COSIGN_CERTIFICATE_OIDC_ISSUER=$OIDC_ISSUER_URL
export COSIGN_YES="true"
export SIGSTORE_FULCIO_URL=$COSIGN_FULCIO_URL
export SIGSTORE_OIDC_ISSUER=$COSIGN_OIDC_ISSUER
export SIGSTORE_REKOR_URL=$COSIGN_REKOR_URL
export REKOR_SERVER=$COSIGN_REKOR_URL

echo "REKOR_SERVER         = $REKOR_SERVER"
echo "SIGSTORE_OIDC_ISSUER = $SIGSTORE_OIDC_ISSUER"
echo "SIGSTORE_FULCIO_URL  = $SIGSTORE_FULCIO_URL"
echo "COSIGN_OIDC_ISSUER   = $COSIGN_OIDC_ISSUER"
echo "COSIGN_MIRROR        = $COSIGN_MIRROR"
echo "COSIGN_ROOT          = $COSIGN_ROOT"
echo "TUF_URL              = $TUF_URL"