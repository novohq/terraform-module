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

#---------------------------------------------------------------------------------------------------------------------
# Set up S3 bucket for logging
#---------------------------------------------------------------------------------------------------------------------

module "iam_iam-assumable-role-with-oidc" {
  source = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "5.27.0"

  create_role = true

  role_name = "ebs-csi-role"

  provider_url  = "${var.openid_connect_provider_url}"

  role_policy_arns = [
    "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  ]
}

 resource "kubernetes_service_account" "ebs_service_account" {
   metadata {
     name      = var.application_name
     namespace = var.namespace
     annotations = {
       "eks.amazonaws.com/role-arn" = module.iam_iam-assumable-role-with-oidc.iam_role_arn
     }
   }
 }

 resource "kubernetes_cluster_role_binding" "ebs_csi_role_binding" {
   metadata {
     name = "ebs-csi-role-binding"
   }
   role_ref {
     api_group = "rbac.authorization.k8s.io"
     kind      = "ClusterRole"
     name      = "ebs-csi-role"
   }
   subject {
     kind      = "ServiceAccount"
     name      = kubernetes_service_account.ebs_service_account.metadata[0].name
     namespace = kubernetes_service_account.ebs_service_account.metadata[0].namespace
   }
 }

