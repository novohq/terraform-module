# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# DEPLOY HELM CHART
# These templates allow you to deploy any Helm chart with Terraform
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

terraform {
  # This module is now only being tested with Terraform 1.1.x. However, to make upgrading easier, we are setting 1.0.0 as the minimum version.
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # This module is compatible with AWS provider ~> 4.6.0, but to make upgrading easier, we are setting 3.75.1 as the minimum version.
      version = ">= 3.75.1"
    }

    helm = {
      source = "hashicorp/helm"
      # NOTE: 2.6.0 has a regression bug that prevents usage of the exec block with data source references, so we exclude
      # that version. See https://github.com/hashicorp/terraform-provider-kubernetes/issues/1464 for more details.
      version = "~> 2.0, != 2.6.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "application" {
  name       = var.application_name
  repository = var.helm_repository
  chart      = var.helm_chart
  version    = var.helm_chart_version
  namespace  = var.namespace
  # repository_key_file        = lookup(var.repository_key_file, null)
  # repository_cert_file       = lookup(var.repository_cert_file, null)
  # repository_ca_file         = lookup(var.repository_ca_file, null)
  # repository_username        = lookup(var.repository_username, null)
  # repository_password        = lookup(var.repository_password, null)
  # force_update               = lookup(var.force_update, true)
  wait                         = var.wait
  # recreate_pods              = lookup(var.recreate_pods, true)
  # max_history                = lookup(var.max_history, 5)
  # lint                       = lookup(var.lint, true)
  # cleanup_on_fail            = lookup(var.cleanup_on_fail, false)
  # create_namespace           = lookup(var.create_namespace, false)
  # disable_webhooks           = lookup(var.disable_webhooks, false)
  # verify                     = lookup(var.verify, false)
  # reuse_values               = lookup(var.reuse_values, false)
  # reset_values               = lookup(var.reset_values, false)
  # atomic                     = lookup(var.atomic, false)
  # skip_crds                  = lookup(var.skip_crds, false)
  # render_subchart_notes      = lookup(var.render_subchart_notes, true)
  # disable_openapi_validation = lookup(var.disable_openapi_validation, false)
  # wait_for_jobs              = lookup(var.wait_for_jobs, false)
  # dependency_update          = lookup(var.dependency_update, false)
  # replace                    = lookup(var.replace, false)
  timeout                    = var.wait_timeout

  helm_chart_values = [
    yamlencode(
      var.helm_chart_values
    ),
  ]

}

# Some charts turn Kubernetes resources from the chart into AWS resources. These are properly destroyed when the
# corresponding Kubernetes resource is destroyed. However, because of the asynchronous nature of
# Kubernetes operations, there is a delay before the respective controllers delete the AWS resources. This can cause
# problems when you are destroying related resources in quick succession (e.g the Route 53 Hosted Zone).
# We can optionally add a wait after the release is destroyed by using a time_sleep resource.
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