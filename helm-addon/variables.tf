# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

// Since this example showcases the IAM Roles for Service Accounts (IRSA), you will need to fill in the OpenID details.
variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Set to null if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
  default     = "sample-app"
}

variable "namespace" {
  description = "The Kubernetes Namespace to deploy the application into."
  type        = string
  default     = "default"
}

variable "aws_region" {
  description = "The AWS region where the EKS cluster lives. Only used when deploying against EKS (var.kubeconfig_auth_type = eks)."
  type        = string
  default     = "eu-west-1"
}

variable "iam_role_name" {
  description = "Name of the IAM role to be created."
  type        = string
  default     = "nginx-test-role"
}

variable "service_account_name" {
  description = "Name of the Kubernetes Service Account to be created."
  type        = string
  default     = "nginx-test-sa"
}

variable "kubeconfig_auth_type" {
  description = "Specifies how to authenticate to the Kubernetes cluster. Must be one of `eks`, `context`, or `service_account`. When `eks`, var.kubeconfig_eks_cluster_name is required. When `context`, configure the kubeconfig path and context name using var.kubeconfig_path and var.kubeconfig_context. `service_account` can only be used if this module is deployed from within a Kubernetes Pod."
  type        = string
  default     = "context"
}

variable "kubeconfig_eks_cluster_name" {
  description = "Name of the EKS cluster where the Namespace will be created. Required when var.kubeconfig_auth_type is `eks`."
  type        = string
  default     = null
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file containing authentication configurations for Kubernetes clusters. Defaults to ~/.kube/config. Only used if var.kubeconfig_auth_type is `context`."
  type        = string
  default     = "~/.kube/config"
}

variable "kubeconfig_context" {
  description = "The name of the context to use for authenticating to the Kubernetes cluster. Defaults to the configured default context in the kubeconfig file. Only used if var.kubeconfig_auth_type is `context`."
  type        = string
  default     = null
}

variable "use_exec_plugin_for_auth" {
  description = "If this variable is set to true, and kubeconfig_auth_type is set to 'eks', then use an exec-based plugin to authenticate and fetch tokens for EKS. This is useful because EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy', and since the native Kubernetes provider in Terraform doesn't have a way to fetch up-to-date tokens, we recommend using an exec-based provider as a workaround. Use the use_kubergrunt_to_fetch_token input variable to control whether kubergrunt or aws is used to fetch tokens."
  type        = bool
  default     = true
}

variable "use_kubergrunt_to_fetch_token" {
  description = "EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To avoid this issue, we use an exec-based plugin to fetch an up-to-date token. If this variable is set to true, we'll use kubergrunt to fetch the token (in which case, kubergrunt must be installed and on PATH); if this variable is set to false, we'll use the aws CLI to fetch the token (in which case, aws must be installed and on PATH). Note this functionality is only enabled if use_exec_plugin_for_auth is set to true and kubeconfig_auth_type is set to 'eks'."
  type        = bool
  default     = true
}
