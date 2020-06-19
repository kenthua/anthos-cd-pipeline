- Namespace patch is not necessary in normal environments
- Create `flux` namespace and apply `secret` before

  ```shell
  kubectl create ns flux

  # create-secret.sh <path/to/your/id_rsa>
  kubectl create secret generic flux-git-deploy \
    --namespace=flux \
    --from-file=identity=<path/to/your/id_rsa>
  
  ```

- Apply flux resources.

  ```shell
  kustomize build | kubectl apply -f -
  ```
  
