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

variable "force_update" {
  description = "Chart name to be installed. The chart name can be local path, a URL to a chart, or the name of the chart if repository is specified. It is also possible to use the <repository>/<chart> format here if you are running Terraform on a system that the repository has been added to with helm repo add but this is not recommended."
  type        = bool
  default     = true
}

variable "max_history" {
  description = "Chart name to be installed. The chart name can be local path, a URL to a chart, or the name of the chart if repository is specified. It is also possible to use the <repository>/<chart> format here if you are running Terraform on a system that the repository has been added to with helm repo add but this is not recommended."
  type        = string
  default     = 10
}

variable "cleanup_on_fail" {
  description = "Chart name to be installed. The chart name can be local path, a URL to a chart, or the name of the chart if repository is specified. It is also possible to use the <repository>/<chart> format here if you are running Terraform on a system that the repository has been added to with helm repo add but this is not recommended."
  type        = bool
  default     = true
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

variable "service_account_exists" {
  description = "When true, and service_account_name is not blank, lookup and assign an existing ServiceAccount in the Namespace to the Pods."
  type        = bool
  default     = false
}

variable "eks_iam_role_for_service_accounts_config" {
  description = "Configuration for using the IAM role with Service Accounts feature to provide permissions to the applications. This expects a map with two properties: `openid_connect_provider_arn` and `openid_connect_provider_url`. The `openid_connect_provider_arn` is the ARN of the OpenID Connect Provider for EKS to retrieve IAM credentials, while `openid_connect_provider_url` is the URL. Leave as an empty string if you do not wish to use IAM role with Service Accounts."
  type = object({
    openid_connect_provider_arn = string
    openid_connect_provider_url = string
  })
  default = {
    openid_connect_provider_arn = ""
    openid_connect_provider_url = ""
  }
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

variable "values_file_path" {
  description = "A local file path where the helm chart values will be emitted. Use to debug issues with the helm chart values. Set to null to prevent creation of the file."
  type        = string
  default     = null
}

variable "expose_type" {
  description = "How the service will be exposed in the cluster. Must be one of `external` (accessible over the public Internet), `internal` (only accessible from within the same VPC as the cluster), `cluster-internal` (only accessible within the Kubernetes network), `none` (deploys as a headless service with no service IP)."
  type        = string
  default     = "ClusterIP"
}

variable "override_chart_inputs" {
  description = "Override any computed chart inputs with this map. This map is shallow merged to the computed chart inputs prior to passing on to the Helm Release. This is provided as a workaround while the terraform module does not support a particular input value that is exposed in the underlying chart. Please always file a GitHub issue to request exposing additional underlying input values prior to using this variable."

  # Ideally we would define a concrete type here, but since the input value spec for the chart has dynamic optional
  # values, we can't use a concrete object type for Terraform. Also, setting a type spec here will defeat the purpose of
  # the escape hatch since it requires defining new input values here before users can use it.
  type = any

  default = {}
}

variable "use_managed_iam_policies" {
  description = "When true, all IAM policies will be managed as dedicated policies rather than inline policies attached to the IAM roles. Dedicated managed policies are friendlier to automated policy checkers, which may scan a single resource for findings. As such, it is important to avoid inline policies when targeting compliance with various security standards."
  type        = bool
  default     = true
}

locals {
  use_inline_policies = var.use_managed_iam_policies == false
}

variable "mq_user" {
  description = "Rabbitmq user"
  type        = string
  default     = "rabbitmq"
}

variable "mq_password" {
  description = "Rabbitmq password"
  type        = string
  default     = "rabbitmq"
}

variable "mq_request_memory" {
  description = "Request memory"
  type        = string
  default     = "1000Mi"
}

variable "mq_request_cpu" {
  description = "Request memory"
  type        = string
  default     = "500m"
}

variable "mq_limit_memory" {
  description = "Limit memory"
  type        = string
  default     = "1000Mi"
}

variable "mq_limit_cpu" {
  description = "Limit memory"
  type        = string
  default     = "500m"
}

