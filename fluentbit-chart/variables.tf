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
  default     = "kube-system"
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

variable "reuse_values" {
  description = "Reuse chart values."
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

variable "request_memory" {
  description = "Request memory"
  type        = string
  default     = "2000Mi"
}

variable "request_cpu" {
  description = "Request memory"
  type        = string
  default     = "1000m"
}

variable "limit_memory" {
  description = "Limit memory"
  type        = string
  default     = "2000Mi"
}

variable "limit_cpu" {
  description = "Limit memory"
  type        = string
  default     = "1000m"
}

## ALB ACM certificate

variable "alb_acm_certificate_arns" {
  description = "A list of ACM certificate ARNs to attach to the ALB. The first certificate in the list will be added as default certificate."
  type        = list(string)
  default     = []
}

# Access point configuration. Used to configure Service and Ingress/ALB (if externally exposed to cluster)

variable "expose_type" {
  description = "How the service will be exposed in the cluster. Must be one of `external` (accessible over the public Internet), `internal` (only accessible from within the same VPC as the cluster), `cluster-internal` (only accessible within the Kubernetes network), `none` (deploys as a headless service with no service IP)."
  type        = string
  default     = "cluster-internal"
}

variable "ingress_configure_ssl_redirect" {
  description = "When true, HTTP requests will automatically be redirected to use SSL (HTTPS). Used only when expose_type is either external or internal."
  type        = bool
  default     = true
}

variable "ingress_ssl_redirect_rule_already_exists" {
  description = "Set to true if the Ingress SSL redirect rule is managed externally. This is useful when configuring Ingress grouping and you only want one service to be managing the SSL redirect rules. Only used if ingress_configure_ssl_redirect is true."
  type        = bool
  default     = false
}

variable "ingress_ssl_redirect_rule_requires_path_type" {
  description = "Whether or not the redirect rule requires setting path type. Set to true when deploying to Kubernetes clusters with version >=1.19. Only used if ingress_configure_ssl_redirect is true."
  type        = bool
  default     = true
}

variable "ingress_listener_protocol_ports" {
  description = "A list of maps of protocols and ports that the ALB should listen on."
  type = list(object({
    protocol = string
    port     = number
  }))
  default = [
    {
      protocol = "HTTP"
      port     = 80
    },
    {
      protocol = "HTTPS"
      port     = 443
    },
  ]
}

variable "ingress_path" {
  description = "Path prefix that should be matched to route to the service. For Kubernetes Versions <1.19, Use /* to match all paths. For Kubernetes Versions >=1.19, use / with ingress_path_type set to Prefix to match all paths."
  type        = string
  default     = "/"
}

variable "ingress_path_type" {
  description = "The path type to use for the ingress rule. Refer to https://kubernetes.io/docs/concepts/services-networking/ingress/#path-types for more information."
  type        = string
  default     = "Prefix"
}

variable "ingress_backend_protocol" {
  description = "The protocol used by the Ingress ALB resource to communicate with the Service. Must be one of HTTP or HTTPS."
  type        = string
  default     = "HTTP"
}

variable "ingress_group" {
  description = "Assign the ingress resource to an IngressGroup. All Ingress rules of the group will be collapsed to a single ALB. The rules will be collapsed in priority order, with lower numbers being evaluated first."
  type = object({
    # Ingress group to assign to.
    name = string
    # The priority of the rules in this Ingress. Smaller numbers have higher priority.
    priority = number
  })
  default = null
}

variable "ingress_target_type" {
  description = "Controls how the ALB routes traffic to the Pods. Supports 'instance' mode (route traffic to NodePort and load balance across all worker nodes, relying on Kubernetes Service networking to route to the pods), or 'ip' mode (route traffic directly to the pod IP - only works with AWS VPC CNI). Must be set to 'ip' if using Fargate. Only used if expose_type is not cluster-internal."
  type        = string
  default     = "instance"
}

variable "service_port" {
  description = "The port to expose on the Service. This is most useful when addressing the Service internally to the cluster, as it is ignored when connecting from the Ingress resource."
  type        = number
  default     = 80
}

variable "ingress_access_logs_s3_bucket_already_exists" {
  description = "Set to true if the S3 bucket to store the Ingress access logs is managed external to this module."
  type        = bool
  default     = false
}

variable "force_destroy_ingress_access_logs" {
  description = "A boolean that indicates whether the access logs bucket should be destroyed, even if there are files in it, when you run Terraform destroy. Unless you are using this bucket only for test purposes, you'll want to leave this variable set to false."
  type        = bool
  default     = false
}

variable "ingress_access_logs_s3_bucket_name" {
  description = "The name to use for the S3 bucket where the Ingress access logs will be stored. If you leave this blank, a name will be generated automatically based on var.application_name."
  type        = string
  default     = ""
}

variable "ingress_access_logs_s3_prefix" {
  description = "The prefix to use for ingress access logs associated with the ALB. All logs will be stored in a key with this prefix. If null, the application name will be used."
  type        = string
  default     = null
}

variable "num_days_after_which_archive_ingress_log_data" {
  description = "After this number of days, Ingress log files should be transitioned from S3 to Glacier. Set to 0 to never archive logs."
  type        = number
  default     = 0
}

variable "num_days_after_which_delete_ingress_log_data" {
  description = "After this number of days, Ingress log files should be deleted from S3. Set to 0 to never delete logs."
  type        = number
  default     = 0
}

variable "ingress_annotations" {
  description = "A list of custom ingress annotations, such as health checks and TLS certificates, to add to the Helm chart. See: https://kubernetes-sigs.github.io/aws-load-balancer-controller/v2.4/guide/ingress/annotations/"
  type        = map(string)
  default     = {}

  # Example:
  # {
  #   "alb.ingress.kubernetes.io/shield-advanced-protection" : "true"
  # }
}

# DNS Info

variable "domain_name" {
  description = "The domain name for the DNS A record to bind to the Ingress resource for this service (e.g. service.foo.com). Depending on your external-dns configuration, this will also create the DNS record in the configured DNS service (e.g., Route53)."
  type        = string
  default     = null
}

variable "domain_propagation_ttl" {
  description = "The TTL value of the DNS A record that is bound to the Ingress resource. Only used if var.domain_name is set and external-dns is deployed."
  type        = number
  default     = null
}

variable "fluentbit_values_file" {
  description = "FluentBit yaml location"
  type        = string
  default     = "values.yaml"
}
variable "bucket_name" {
  description = "bucket name"
  type        = string
  default     = ""
}
variable "region" {
  description = "region"
  type        = string
  default     = ""
}
variable "account_id" {
  description = "account"
  type        = string
  default     = ""
}
variable "expiration_days" {
  description = "object expiration days"
  type        = number
  default     = "1200"
}
