argocd app sync pacman-ci
oc create -f ci-application/pipelineRun.yaml -n pacman-ci
