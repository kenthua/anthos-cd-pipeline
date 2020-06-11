# Automated Pipeline for Sample Applications

## Sample Apps
- [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos)
- [Hipster Shop](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) (istio)
- Bank of Anthos multi-cluster
  - cluster 1 (gcp) - balancer-reader, frontend, ledger-db, ledger-writer, loadgenerator, transaction-history
  - cluster 2 (aws) - accounts-db, contacts, user-service
- Hipster Shop multi-cluster
  - cluster 1 (gcp) - adservice, checkoutservice, currencyservice, emailservice, frontend, loadgenerator, paymentservice, productcatalogservice, recommendationservice, shippingservice
  - cluster 2 (aws) - cartservice, redis

## argocd
Argocd is configured in `infra` to automatically pipeline deploy `argocd-platform`, `bank of anthos`, `hipster shop`, and `bookinfo`.

## Multi-cluster deployment, based on [istio replicated control planes](https://istio.io/docs/setup/install/multicluster/gateways/) - Tested with ASM 1.5.4
- Istio
  - Setup shared istio certificates

    ```shell
    kubectl create ns istio-system

    kubectl create secret generic cacerts -n istio-system \
    --from-file=samples/certs/ca-cert.pem \
    --from-file=samples/certs/ca-key.pem \
    --from-file=samples/certs/root-cert.pem \
    --from-file=samples/certs/cert-chain.pem
    ```

  - Install replicated control plane istio applicable to enivronment.

    ```shell
    # cluster 1 (gcp) in infra/istio
    # this istio is also setup to send metrics to cloud monitoring
    # NOTE: if workload identity is enabled in the cluster, metrics won't work.
    istioctl manifest apply -f istio-mc.yaml

    # cluster 2 (aws) in infra/istio
    istioctl manifest apply -f istio-mc-aws.yaml
    ```

  - Setup DNS (per instructions)

    ```shell
    # cluster 1
    kubectl apply -f cm-kube-dns.yaml
    
    # cluster 2
    kubectl apply -f cm-coredns.yaml
    ```

## App Specific
- Bank of Anthos
  - Generate RSA key pair in mc/resources

    ```shell
    openssl genrsa -out jwtRS256.key 4096
    openssl rsa -in jwtRS256.key -outform PEM -pubout -out jwtRS256.key.pub
    ```

- Multi-cluster - Bank of Anthos / Hipster 
  - Modify `$APP-mc/overlays/c1-gcp` with appropriate remote ingress gateway address

    ```shell
    export REMOTE_ADDRESS=your_remote_address
    sed -i "s/REMOTE_ADDRESS/${REMOTE_ADDRESS}/g" $APP-mc/overlays/c1-gcp/serviceentry-patch.yaml
    ```

  - Deploy each folder `$APP-mc/overlays/c1-gcp` & `$APP-mc/overlays/c2-aws` to their respective clusters

    ```shell
    kustomize build | kubectl apply -f -
    ```
