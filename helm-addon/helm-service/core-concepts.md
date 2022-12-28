## How do I assign IAM permissions to a service?

If the underlying Helm chart supports required values and annotations, you can use the [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html) feature. You can use this feature to create an IAM role with a policy and map it to a service account, or map an existing role.

To create a new role:

* Set `iam_role_exists=false`
* Provide an `iam_role_name` that conforms to the [IAM Name Requirements](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-quotas.html)
* Provide a `service_account_name`
* Provide an `iam_policy`. Note that this only supports simple policies with a list of actions, resources, and an effect. For more complex policies, create the role and attach the policies in a separate module.
* In `eks_iam_role_for_service_accounts_config`, provide OpenID Connect Provider details. See the variable description for more information.
* In `helm_chart_values`, provide necessary values, e.g.

```hcl
  helm_chart_values = {
    serviceAccount = {
      create = "true"
      name   = "your_service_account_name"
      annotations = {
        "eks.amazonaws.com/role-arn" = "your_iam_role_arn"
      }
    }
  }
```

Note that the values for Service Account and the Role ARN specified in `helm_chart_values` have to match the values provided with `service_account_name` and `iam_role_name`.

To use an existing role:

* Set `iam_role_exists=true` 
* Provide the existing role in `iam_role_name`. You won't need to set `iam_policy`.
* Provide a `service_account_name`
* In `eks_iam_role_for_service_accounts_config`, provide OpenID Connect Provider details. See the variable description for more information.
* In `helm_chart_values`, provide necessary values, as in the example above.

