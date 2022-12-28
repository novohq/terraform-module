provider "aws" {
  region = var.aws_region

  # Skip all checks if not using eks auth, as they are unnecessary.
  skip_credentials_validation = var.kubeconfig_auth_type != "eks"
  skip_get_ec2_platforms      = var.kubeconfig_auth_type != "eks"
  skip_region_validation      = var.kubeconfig_auth_type != "eks"
  skip_requesting_account_id  = var.kubeconfig_auth_type != "eks"
  skip_metadata_api_check     = var.kubeconfig_auth_type != "eks"
}

# Configure the Helm provider based on the requested authentication type.
provider "helm" {
  kubernetes {
    # If using `context`, load the authentication info from the config file and chosen context.
    config_path    = var.kubeconfig_auth_type == "context" ? pathexpand(var.kubeconfig_path) : null
    config_context = var.kubeconfig_auth_type == "context" ? var.kubeconfig_context : null

    # If using `eks`, load the authentication info directly from EKS.
    host                   = var.kubeconfig_auth_type == "eks" ? data.aws_eks_cluster.cluster[0].endpoint : null
    cluster_ca_certificate = var.kubeconfig_auth_type == "eks" ? base64decode(data.aws_eks_cluster.cluster[0].certificate_authority.0.data) : null
    token                  = var.kubeconfig_auth_type == "eks" && var.use_exec_plugin_for_auth == false ? data.aws_eks_cluster_auth.kubernetes_token[0].token : null

    # EKS clusters use short-lived authentication tokens that can expire in the middle of an 'apply' or 'destroy'. To
    # avoid this issue, we use an exec-based plugin here to fetch an up-to-date token. Note that this code requires a
    # binary — either kubergrunt or aws — to be installed and on your PATH.
    dynamic "exec" {
      for_each = var.kubeconfig_auth_type == "eks" && var.use_exec_plugin_for_auth ? ["once"] : []

      content {
        api_version = "client.authentication.k8s.io/v1beta1"
        command     = var.use_kubergrunt_to_fetch_token ? "kubergrunt" : "aws"
        args = (
          var.use_kubergrunt_to_fetch_token
          ? ["eks", "token", "--cluster-id", var.kubeconfig_eks_cluster_name]
          : ["eks", "get-token", "--cluster-name", var.kubeconfig_eks_cluster_name]
        )
      }
    }
  }
}

# Pull in caller identity to get the AWS Account ID
data "aws_caller_identity" "current" {}

# This is to showcase how you can use IAM Roles For Service Accounts (IRSA) to grant IAM permissions for the application.
# Note that the example application does not make use of any IAM permissions.
locals {
  iam_role_arn = format("arn:aws:iam::%s:role/%s", data.aws_caller_identity.current.account_id, var.iam_role_name)
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

module "helm_addon" {
  source               = "../helm-service"
  helm_repository      = var.helm_repository
  helm_chart           = var.helm_chart
  helm_chart_version   = var.helm_chart_version
  application_name     = var.application_name
  namespace            = var.namespace

  helm_chart_values = {
    nameOverride = var.application_name
    serviceAccount = {
      create = "true"
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = local.iam_role_arn
      }
    }
    service = {
      type = "ClusterIP"
    }
  }

  eks_iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config

  iam_policy = {
    S3Access = {
      actions   = ["s3:List*"]
      resources = ["*"]
      effect    = "Allow"
    },
  }
}

resource "time_sleep" "wait_30_seconds" {
  count = var.sleep_for_resource_culling ? 1 : 0

  depends_on = [helm_release.application]

  destroy_duration = "30s"
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP AN OPTIONAL IAM ROLE FOR SERVICE ACCOUNT (IRSA)
# Set up IRSA if a service account and IAM role are configured.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "new_role" {
  count = local.should_create_new_role ? 1 : 0

  name               = var.iam_role_name
  assume_role_policy = module.service_account_assume_role_policy[0].assume_role_policy_json
}

module "service_account_assume_role_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-iam-role-assume-role-policy-for-service-account?ref=v0.55.2"

  count = local.should_create_new_role ? 1 : 0

  eks_openid_connect_provider_arn = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_arn
  eks_openid_connect_provider_url = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_url
  namespaces                      = []
  service_accounts = [{
    name      = var.service_account_name
    namespace = var.namespace
  }]
}

resource "aws_iam_role_policy" "service_policy" {
  count = local.should_create_policy ? 1 : 0

  name   = "${var.iam_role_name}-policy"
  role   = var.iam_role_name
  policy = data.aws_iam_policy_document.service_policy[0].json

  depends_on = [aws_iam_role.new_role]
}

data "aws_iam_policy_document" "service_policy" {
  count = local.should_create_policy ? 1 : 0

  dynamic "statement" {
    for_each = var.iam_policy

    content {
      sid       = statement.key
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

data "aws_iam_role" "existing_role" {
  count = var.iam_role_exists ? 1 : 0
  name  = var.iam_role_name
}

locals {
  should_create_new_role = var.iam_role_name != "" && var.iam_role_exists == false && var.eks_iam_role_for_service_accounts_config != null
  should_create_policy   = (var.iam_role_exists || var.iam_role_name != "") && var.iam_policy != null
}
