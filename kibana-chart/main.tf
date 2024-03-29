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
  namespace       = var.namespace
  force_update    = var.force_update
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

  values = [
    yamlencode(
      merge(
        local.helm_chart_input,
        var.override_chart_inputs,
      ),
    ),
  ]
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

  alb_health_check = {
    "alb.ingress.kubernetes.io/healthcheck-port"             = var.alb_health_check_port
    "alb.ingress.kubernetes.io/healthcheck-protocol"         = var.alb_health_check_protocol
    "alb.ingress.kubernetes.io/healthcheck-path"             = var.alb_health_check_path
    "alb.ingress.kubernetes.io/healthcheck-interval-seconds" = tostring(var.alb_health_check_interval)
    "alb.ingress.kubernetes.io/healthcheck-timeout-seconds"  = tostring(var.alb_health_check_timeout)
    "alb.ingress.kubernetes.io/healthy-threshold-count"      = tostring(var.alb_health_check_healthy_threshold)
    "alb.ingress.kubernetes.io/success-codes"                = var.alb_health_check_success_codes
  }

  # Assemble a complete map of ingress annotations
  ingress_annotations = merge(
    {
      #"kubernetes.io/ingress.class"      = "alb"
      "alb.ingress.kubernetes.io/scheme" = var.expose_type == "external" ? "internet-facing" : "internal"
      # We manually construct the list as a string here to avoid the values being converted as string, as opposed to
      # ints
      "alb.ingress.kubernetes.io/listen-ports"     = "[${join(",", local.ingress_listener_protocol_ports)}]"
      "alb.ingress.kubernetes.io/backend-protocol" = var.ingress_backend_protocol
    },
    (
      var.ingress_group != null
      ? {
        "alb.ingress.kubernetes.io/group.name" = var.ingress_group.name
      }
      : {}
    ),
    (
      # NOTE: can't use && because Terraform processes the conditional in one pass, and boolean operators are not short
      # circuit.
      var.ingress_group != null
      ? (
        var.ingress_group.priority != null
        ? {
          "alb.ingress.kubernetes.io/group.order" = tostring(var.ingress_group.priority)
        }
        : {}
      )
      : {}
    ),
    (
      var.domain_propagation_ttl != null
      ? {
        "external-dns.alpha.kubernetes.io/ttl" = tostring(var.domain_propagation_ttl)
      }
      : {}
    ),
    {
      "alb.ingress.kubernetes.io/certificate-arn" = join(",", var.alb_acm_certificate_arns),
      "alb.ingress.kubernetes.io/target-type"     = var.ingress_target_type
    },
    var.ingress_annotations,
  )

  helm_chart_input = merge(
    {
      elasticsearchHosts                      = var.es_host
      elasticsearchCertificateSecret          = var.es_certificate_secret
      elasticsearchCertificateAuthoritiesFile = var.es_ca_file
      elasticsearchCredentialSecret           = var.es_master_pass
      #nameOverride       = var.application_name

      serviceAccount = {
        # Create a new service account if service_account_name is not blank and it is not referring to an existing Service
        # Account
        # create = (!var.service_account_exists) && var.service_account_name != ""

        # name        = var.service_account_name
        # namespace   = var.namespace
        # annotations = local.iam_role == "" ? {} : { "eks.amazonaws.com/role-arn" = local.iam_role }
      }
      service = {
        # When expose_type is cluster-internal, we do not want to associate an Ingress resource, or allow access
        # externally from the cluster, so we use ClusterIP service type.
        type = (
          var.expose_type == "cluster-internal" || var.expose_type == "none"
          ? "ClusterIP"
          : "NodePort"
        )
      }
      ingress = {
        enabled     = true
        className   = "alb"
        annotations = local.ingress_annotations
        hosts = [
          {
            host = var.domain_name,
            paths : [
              {
                path : var.ingress_path
              }
            ]
          }
        ]
      }
      extraEnvs = [
      {
        "name": "NODE_OPTIONS",
        "value": "--max-old-space-size=1800"
      },
      {
      "name": "KIBANA_OBJECT_ENCRYPTION_KEY",
        "valueFrom": {
          "secretKeyRef": {
            "name": "kibana-savedobject-key",
            "key": "encryptionkey"
          }
        }
      },
      {
      "name": "KIBANA_REPORTING_ENCRYPTION_KEY",
        "valueFrom": {
          "secretKeyRef": {
            "name": "kibana-reporting-key",
            "key": "encryptionkey"
          }
        }
      },
      {
      "name": "KIBANA_SECURITY_ENCRYPTION_KEY",
        "valueFrom": {
          "secretKeyRef": {
            "name": "kibana-security-key",
            "key": "encryptionkey"
          }
        }
      }]
      kibanaConfig = jsondecode(file("kibana.json"))
      resources = {
        requests = {
          memory = var.request_memory,
          cpu    = var.request_cpu
        },
        limits = {
          memory = var.limit_memory,
          cpu    = var.limit_cpu
        }
      }
    },
  )
  # We use interpolate a string here to construct a list of protocol port mappings for the listener, that can then be injected
  # into the input values. We do this instead of directly rendering the list because terraform does some type conversions
  # in the yaml encode process.
  ingress_listener_protocol_ports = [
    for protocol_ports in var.ingress_listener_protocol_ports :
    "{\"${protocol_ports["protocol"]}\": ${protocol_ports["port"]}}"
  ]
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

# ---------------------------------------------------------------------------------------------------------------------
# EMIT HELM CHART VALUES TO DISK FOR DEBUGGING
# ---------------------------------------------------------------------------------------------------------------------

resource "local_file" "debug_values" {
  count = var.values_file_path != null ? 1 : 0

  content         = yamlencode(local.helm_chart_input)
  filename        = var.values_file_path
  file_permission = "0644"
}