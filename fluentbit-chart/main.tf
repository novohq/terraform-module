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
      # AWS provider 4.x was released with backward incompatibilities that this module is not yet adapted to.
      version = ">= 3.75.1"
    }

    helm = {
      source = "hashicorp/helm"
      # NOTE: 2.6.0 has a regression bug that prevents usage of the exec block with data source references, so we lock
      # to a version less than that. See https://github.com/hashicorp/terraform-provider-kubernetes/issues/1464 for more
      # details.
      version = "~> 2.0, < 2.6.0"
    }
  }
}

# ---------------------------------------------------------------------------------------------------------------------
# DEPLOY HELM CHART
# ---------------------------------------------------------------------------------------------------------------------

resource "helm_release" "application" {
  name            = var.application_name
  repository      = var.helm_repository
  chart           = var.helm_chart
  version         = var.helm_chart_version
  force_update    = var.force_update
  namespace       = var.namespace
  wait            = var.wait
  max_history     = var.max_history
  cleanup_on_fail = var.cleanup_on_fail
  timeout         = var.wait_timeout
  reuse_values    = var.reuse_values
  # create_namespace           = lookup(var.create_namespace, false)
  # disable_webhooks           = lookup(var.disable_webhooks, false)
  # verify                     = lookup(var.verify, false)
  # reset_values               = lookup(var.reset_values, false)
  # atomic                     = lookup(var.atomic, false)
  # skip_crds                  = lookup(var.skip_crds, false)
  # render_subchart_notes      = lookup(var.render_subchart_notes, true)
  # disable_openapi_validation = lookup(var.disable_openapi_validation, false)
  # wait_for_jobs              = lookup(var.wait_for_jobs, false)
  # dependency_update          = lookup(var.dependency_update, false)
  # replace                    = lookup(var.replace, false)
  # recreate_pods              = lookup(var.recreate_pods, true)
  # lint                       = lookup(var.lint, true)

  values = [templatefile("values.yaml", {
    AWS_BUCKET = module.s3_bucket.primary_bucket_name
    AWS_REGION = var.region
  })]
  depends_on = [null_resource.sleep_for_resource_culling]
}
# Some charts turn Kubernetes resources from the chart into AWS resources. These are properly destroyed when the
# corresponding Kubernetes resource is destroyed. However, because of the asynchronous nature of
# Kubernetes operations, there is a delay before the respective controllers delete the AWS resources. This can cause
# problems when you are destroying related resources in quick succession (e.g the Route 53 Hosted Zone).
# We can optionally add a wait after the release is destroyed by using a time_sleep resource.
resource "null_resource" "sleep_for_resource_culling" {
  triggers = {
    should_run = (
      var.expose_type != "cluster-internal" && var.expose_type != "none"
      ? "true"
      : "false"
    )
  }

  provisioner "local-exec" {
    command = (
      self.triggers["should_run"] == "true"
      ? "echo 'Sleeping for 30 seconds to allow Kubernetes time to remove associated AWS resources'; sleep 30"
      : "echo 'Skipping sleep to wait for Kubernetes to cull AWS resources, since k8s-service has none associated with it.'"
    )
    when = destroy
  }
}

locals {
  iam_role = (
    var.iam_role_name != ""
    ? (
      var.iam_role_exists
      ? data.aws_iam_role.existing_role[0].arn
      : aws_iam_role.new_role[0].arn
    )
    : ""
  )
}

#---------------------------------------------------------------------------------------------------------------------
# Set up S3 bucket for logging
#---------------------------------------------------------------------------------------------------------------------
module "s3_bucket" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-service-catalog.git//modules/data-stores/s3-bucket?ref=v0.104.6"

  primary_bucket        = var.bucket_name

  # Ownership
  # bucket_ownership                = "BucketOwnerEnforced"
  # access_logging_bucket_ownership = "ObjectWriter"
  # replica_bucket_ownership        = "BucketOwnerEnforced"

  # Grant read and write access to the current IAM user running this module
  bucket_policy_statements = {
    AllowCurrentUserReadWriteAccess = {
      effect = "Allow"
      actions = [
        "s3:Get*",
        "s3:List*",
        "s3:Put*"
      ]
      principals = {
        AWS = ["arn:aws:iam::${var.account_id}:root"]
      }
    }
  }

  # variable "lifecycle_rules" {
  #   {
  #    deep_archive = {
  #      prefix  = "/"
  #      enabled = true
  
  #      transition = {
  #        ToGlacier = {
  #          days          = 20
  #          storage_class = "DEEP_ARCHIVE"
  #        }
  #      }
  
  #      noncurrent_version_expiration = 90
  #     }
  #   }
  # }
}

# ---------------------------------------------------------------------------------------------------------------------
# SET UP IAM ROLE FOR SERVICE ACCOUNT
# Set up IRSA if a service account and IAM role are configured.
# ---------------------------------------------------------------------------------------------------------------------

resource "aws_iam_role" "new_role" {
  count = var.iam_role_name != "" && var.iam_role_exists == false ? 1 : 0

  name               = var.iam_role_name
  assume_role_policy = module.service_account_assume_role_policy.assume_role_policy_json
}




module "service_account_assume_role_policy" {
  source = "git::git@github.com:gruntwork-io/terraform-aws-eks.git//modules/eks-iam-role-assume-role-policy-for-service-account?ref=v0.56.1"

  eks_openid_connect_provider_arn = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_arn
  eks_openid_connect_provider_url = var.eks_iam_role_for_service_accounts_config.openid_connect_provider_url
  namespaces                      = []
  service_accounts = [{
    name      = var.service_account_name
    namespace = var.namespace
  }]
}

resource "aws_iam_role_policy" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && local.use_inline_policies ? 1 : 0

  name   = "${var.iam_role_name}Policy"
  role   = var.iam_role_name != "" && var.iam_role_exists == false ? aws_iam_role.new_role[0].id : data.aws_iam_role.existing_role[0].id
  policy = data.aws_iam_policy_document.service_policy[0].json
}

resource "aws_iam_policy" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && var.use_managed_iam_policies ? 1 : 0

  name_prefix = "${var.iam_role_name}-policy"
  policy      = data.aws_iam_policy_document.service_policy[0].json
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  count = var.iam_role_name != "" && var.iam_role_exists == false && var.use_managed_iam_policies ? 1 : 0

  role       = var.iam_role_name != "" && var.iam_role_exists == false ? aws_iam_role.new_role[0].id : data.aws_iam_role.existing_role[0].id
  policy_arn = aws_iam_policy.service_policy[0].arn
}

data "aws_iam_policy_document" "service_policy" {
  count = var.iam_role_name != "" ? 1 : 0

  dynamic "statement" {
    for_each = var.iam_policy == null ? {} : var.iam_policy

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

  name = var.iam_role_name
}