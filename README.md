# Automated Pipeline for Sample Applications

## Sample Apps
- [Bank of Anthos](https://github.com/GoogleCloudPlatform/bank-of-anthos)
- [Hipster Shop](https://github.com/GoogleCloudPlatform/microservices-demo)
- [Bookinfo](https://istio.io/latest/docs/examples/bookinfo/) (istio)
- Bank of Anthos multi-cluster
  - cluster 1 (gcp) - balancer-reader, frontend, ledger-db, ledger-writer, loadgenerator, transaction-history
  - cluster 2 (aws/X) - accounts-db, contacts, user-service
- Hipster Shop multi-cluster
  - cluster 1 (gcp) - adservice, checkoutservice, currencyservice, emailservice, frontend, loadgenerator, paymentservice, productcatalogservice, recommendationservice, shippingservice
  - cluster 2 (aws/X) - cartservice, redis

> NOTE: cluster does not have to be Anthos GKE on AWS

## argocd
Argocd is configured in `infra` to automatically pipeline deploy `argocd-platform`, `bank of anthos`, and `hipster shop`.  `Bookinfo` is deployed, but automatic sync is disabled in favor of fluxcd in this example.

## fluxcd
Fluxcd is configured in `infra` to automatically pipeline deploy `bookinfo`.

## Multi-cluster deployment, based on [istio replicated control planes](https://istio.io/docs/setup/install/multicluster/gateways/)
> NOTE: Tested with ASM binary 1.5.4, 1.5.5
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
    # NOTE: if workload identity is enabled in the cluster:
    #   Each deployment service account will need the iam policy binding to namespace/KSA
    #   Each KSA will need to be annotated with the GSA
    #   See below under workload identity section
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

- Istio Gateway / VirtualService host
  - In each Application, `bank of anthos`, `hipster`, and `bookinfo`, there are specific `*-patch.yaml` resources in `$APP/overlays/gcp`.  Each resource points to a specific host entry, these may need to be modified to support your environment.  You will need individual DNS or wildcard DNS entries pointing to the `istio-ingressgateway` load balancer IP.

- Multi-cluster - Bank of Anthos / Hipster 
  - Modify `$APP-mc/overlays/c1-gcp` with appropriate remote ingress gateway address

    ```shell
    export REMOTE_ADDRESS=your_remote_address
    sed -i "s/REMOTE_ADDRESS/${REMOTE_ADDRESS}/g" $APP-mc/overlays/c1-gcp/serviceentry-patch.yaml
    ```

  - Deploy each folder `$APP-mc/overlays/c1-gcp` & `$APP-mc/overlays/c2-aws` to their respective clusters
    > NOTE: kustomize 3.6.1+ is needed to use remote resources as http

    ```shell
    kustomize build | kubectl apply -f -
    ```

## Workload Identity
- Create the role and assign permissions

  ```shell
  PROJECT_ID=<your_project_id>
  GSA_NAME=<your_google_service_account_name | i.e. telemetry>
  KSA_NAME=<kubernets service account | i.e. default>
  K8S_NAMESPACE=<kubernetes namespace | i.e hipster>

  # derive from above settings
  GSA=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com

  # create the service account
  gcloud iam service-accounts create $GSA_NAME

  # assign the context graph role
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/contextgraph.asserter \
  --member "serviceAccount:$GSA"

  # assign log writer
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/logging.logWriter \
  --member "serviceAccount:$GSA"

  # assign metric writer
  gcloud projects add-iam-policy-binding $PROJECT_ID \
  --role roles/monitoring.metricWriter \
  --member "serviceAccount:$GSA"
  ```

- Map GSA to KSA for Workload Identity
  ```shell
  # assign workload identity mapping to kubernetes resources
  gcloud iam service-accounts add-iam-policy-binding $GSA \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[$K8S_NAMESPACE/$KSA_NAME]"

  # annotate ksa with gsa for workload identity
  kubectl annotate serviceaccount \
  --namespace $K8S_NAMESPACE \
  $KSA_NAME \
  iam.gke.io/gcp-service-account=$GSA
  ```
