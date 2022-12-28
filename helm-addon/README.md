```hcl
module "nginx" {
   source               = "../../../../modules/services/helm-service"
   helm_repository      = "https://charts.bitnami.com/bitnami"
   helm_chart           = "nginx"
   helm_chart_version   = "13.1.6"
   application_name     = var.application_name
   namespace            = var.namespace
   service_account_name = var.service_account_name
   iam_role_name        = var.iam_role_name
  ...
```