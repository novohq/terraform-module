provider "aws" {
  region = var.aws_region

  # Skip all checks if not using eks auth, as they are unnecessary.
  skip_credentials_validation = var.kubeconfig_auth_type != "eks"
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
    # binary—either kubergrunt or aws—to be installed and on your PATH.
    dynamic "exec" {
      for_each = var.kubeconfig_auth_type == "eks" && var.use_exec_plugin_for_auth ? ["once"] : []

      content {
        api_version = "client.authentication.k8s.io/v1"
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
  source               = ".//helm-service"
  helm_repository      = var.helm_repository
  helm_chart           = var.helm_chart
  helm_chart_version   = var.helm_chart_version
  application_name     = var.application_name
  namespace            = var.namespace

  helm_chart_values = [
    yamlencode(
      var.helm_chart_values
    ),
    nameOverride = var.application_name
    serviceAccount = {
      create = "true"
      name   = var.service_account_name
      annotations = {
        "eks.amazonaws.com/role-arn" = local.iam_role_arn
      }
    }
  ]

  # helm_chart_values = {
  #   nameOverride = var.application_name
  #   serviceAccount = {
  #     create = "true"
  #     name   = var.service_account_name
  #     annotations = {
  #       "eks.amazonaws.com/role-arn" = local.iam_role_arn
  #     }
  #   }
  #   service = {
  #     type = "ClusterIP"
  #   }
  # }

  eks_iam_role_for_service_accounts_config = var.eks_iam_role_for_service_accounts_config

  iam_policy = {
    S3Access = {
      actions   = ["s3:List*"]
      resources = ["*"]
      effect    = "Allow"
    },
  }
}