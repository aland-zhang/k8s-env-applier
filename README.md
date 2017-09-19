# k8s-env-applier

This simple bash script applies all the YAML files in the current dir and environment specific patches. It can also set the image for one container.

It allows one to manage environment specific configuration in a unified and simple way. One may have a different storage class between dev and prod, or different ingress between minikube and one's cloud provider. It allows one to apply certain YAML files only in certain environments, and to patch common configurations per environment. *All patches are done before applying the result to the environment.*

## Download

    wget --quiet https://raw.githubusercontent.com/foundery-rmb/k8s-env-applier/master/apply-all-yamls-with-patches.sh -O apply-all-yamls-with-patches.sh && chmod u+x apply-all-yamls-with-patches.sh

## Usage

Run either with parameters or environment variables set. To see detailed usage info, simply run

    ./apply-all-yamls-with-patches.sh

If no environment patches are to be applied, provide a non-existent directory.

## Features

- Apply \*.yaml in the working directory to a namespace using `kubectl`
- Apply \*.yaml in the environment specific _patch_ directory
- Perform a merge patch on a resource
- Perform a json patch on a resource
- Update the image tag in a spec

## Requirements

- Exactly one object per YAML file is expected
- In the environment _patch_ directory exactly zero or one json patch file with the form "patch-resource-name.json" is expected
- In the environment _patch_ directory exactly zero or one merge patch file with the form "patch-resource-name.yaml" is expected

## Limitations

- Only one image tag can be updated at a time
