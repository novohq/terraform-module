#---------------------------------------------------------------------------------------------------------------------
# REQUIRED MODULE PARAMETERS
# These variables must be passed in by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "application_name" {
  description = "The name of the application (e.g. my-service-stage). Used for labeling Kubernetes resources."
  type        = string
}

variable "namespace" {
  description = "The Kubernetes Namespace to deploy the helm chart into."
  type        = string
}

variable "helm_repository" {
  description = "Repository URL where to locate the requested chart."
  type        = string
}

variable "helm_chart" {
  description = "Chart name to be installed. The chart name can be local path, a URL to a chart, or the name of the chart if repository is specified. It is also possible to use the <repository>/<chart> format here if you are running Terraform on a system that the repository has been added to with helm repo add but this is not recommended."
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL MODULE PARAMETERS
# These variables have defaults, but may be overridden by the operator.
# ---------------------------------------------------------------------------------------------------------------------

variable "helm_chart_version" {
  description = "Specify the exact chart version to install. If this is not specified, the latest version is installed."
  type        = string
  default     = null
}

variable "helm_chart_values" {
  description = "Map of values to pass to the Helm chart. Leave empty to use chart default values."
  type        = any
  default     = {}
}

variable "iam_role_exists" {
  description = "Whether or not the IAM role passed in `iam_role_name` already exists. Set to true if it exists, or false if it needs to be created. Defaults to false."
  type        = bool
  default     = false
}

variable "iam_role_name" {
  description = "The name of an IAM role that will be used by the pod to access the AWS API. If `iam_role_exists` is set to false, this role will be created. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type        = string
  default     = ""
}

variable "service_account_name" {
  description = "The name of a service account to create for use with the Pods. This service account will be mapped to the IAM role defined in `var.iam_role_name` to give the pod permissions to access the AWS API. Must be unique in this namespace. Leave as an empty string if you do not wish to assign a Service Account to the Pods."
  type        = string
  default     = ""
}

variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
  default = null
}

variable "iam_policy" {
  description = "An object defining the policy to attach to `iam_role_name` if the IAM role is going to be created. Accepts a map of objects, where the map keys are sids for IAM policy statements, and the object fields are the resources, actions, and the effect (\"Allow\" or \"Deny\") of the statement. Ignored if `iam_role_arn` is provided. Leave as null if you do not wish to use IAM role with Service Accounts."
  type = map(object({
    resources = list(string)
    actions   = list(string)
    effect    = string
  }))
  default = null

  # Example:
  # iam_policy = {
  #   S3Access = {
  #     actions = ["s3:*"]
  #     resources = ["arn:aws:s3:::mybucket"]
  #     effect = "Allow"
  #   },
  #   SecretsManagerAccess = {
  #     actions = ["secretsmanager:GetSecretValue"],
  #     resources = ["arn:aws:secretsmanager:us-east-1:0123456789012:secret:mysecert"]
  #     effect = "Allow"
  #   }
  # }
}

# Helm release configurations

variable "wait" {
  description = "When true, wait until Pods are up and healthy or wait_timeout seconds before exiting terraform."
  type        = bool
  default     = true
}

variable "wait_timeout" {
  description = "Number of seconds to wait for Pods to become healthy before marking the deployment as a failure."
  type        = number
  default     = 300
}

variable "sleep_for_resource_culling" {
  description = "Sleep for 30 seconds to allow Kubernetes time to remove associated AWS resources."
  type        = bool
  default     = false
}
