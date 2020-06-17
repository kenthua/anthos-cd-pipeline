- Namespace patch is not necessary in normal environments
- Create `flux` namespace and apply `secret` before:
  ```shell
  kustomize build | kubectl apply -f -
  ```
