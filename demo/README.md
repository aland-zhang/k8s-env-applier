# DEMO

## Download

    wget --quiet https://raw.githubusercontent.com/foundery-rmb/k8s-env-applier/master/apply-all-yamls-with-patches.sh -O apply-all-yamls-with-patches.sh && chmod u+x apply-all-yamls-with-patches.sh

## Run in minikube

### Prerequisites 

Enable ingress:

    minikube addons enable ingress

Add hostnames to `/etc/hosts`

    echo "$(minikube ip) myminikube.info helloworld.io" | sudo tee -a /etc/hosts

Create a namespace

    kubectl create namespace demo

### Apply unpatched config

To apply the setup with no changes, use a non-existent patch directory:

    ./apply-all-yamls-with-patches.sh demo blablabla
    
Browse to http://myminikube.info to see the "Hello World!" message.
    
### Apply config with different image tag

It is useful in continuous deployment (CD) to update the image tag in one's build pipeline. One may do it like this:

    ./apply-all-yamls-with-patches.sh demo blablabla nginx 1.13.5-alpine

### Apply patches

Suppose in a production environment one has different configurations. Apply with patches in the `prod` directory:

    ./apply-all-yamls-with-patches.sh demo prod
    
Browse to http://helloworld.io to see the "Hello World from ACME!" message.
    
The patches do:
- Add a different config map for index.html
- Replace the volumes section for the deployment to mount the prod index.html instead
- Update the hostname in the ingress in two steps:
    - Because the ingress rules are an array, first use the _test_ operation to check that the value is what is expected
    - Replace the hostname with "helloworld.io" using the _replace_ operation
