<!-- Frontmatter
type: service
name: Helm Service
description: Deploy any Helm chart using Terraform
cloud: aws
tags: ["helm", "docker", "orchestration", "kubernetes", "containers"]
license: gruntwork
built-with: terraform, helm
-->

# Helm Service

![Maintained by Gruntwork](https://img.shields.io/badge/maintained%20by-gruntwork.io-%235849a6.svg)
![Terraform version](https://img.shields.io/badge/tf-%3E%3D1.1.0-blue.svg)
![Helm version](https://img.shields.io/badge/helm-%3E%3D3.1.0-green)

## Overview

This service contains [Terraform](https://www.terraform.io) code to deploy an arbitrary [Helm chart](https://helm.sh/) to
[Kubernetes](https://kubernetes.io/) following best practices.

This module is intended to deploy third-party applications already packaged as Helm Charts, such as those available in [bitnami](https://bitnami.com/stacks/helm). If you want to deploy your own application containers to Kubernetes, see the [`k8s-service`](../k8s-service) module. 

![Kubernetes Service architecture](/_docs/k8s-service-architecture.png?raw=true)

## Features

- Deploy any Helm chart using Terraform
- Managed with Helm

## Learn

> **NOTE**
>
> This repo is a part of the [Gruntwork Service Catalog](https://github.com/gruntwork-io/terraform-aws-service-catalog/),
> a collection of reusable, battle-tested, production ready infrastructure code.
> If you’ve never used the Service Catalog before, make sure to read
> [How to use the Gruntwork Service Catalog](https://docs.gruntwork.io/reference/services/intro/overview)!

### Core concepts

- [Kubernetes core concepts](https://docs.gruntwork.io/guides/build-it-yourself/kubernetes-cluster/core-concepts/what-is-kubernetes):
  learn about Kubernetes architecture (control plane, worker nodes), access control (authentication, authorization,
  resources (pods, controllers, services, config, secrets), and more.

- [How do you run applications on Kubernetes?](https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/core-concepts.md#how-do-you-run-applications-on-kubernetes)

- [What is Helm?](https://github.com/gruntwork-io/helm-kubernetes-services/blob/master/core-concepts.md#what-is-helm)

- *[Kubernetes in Action](https://www.manning.com/books/kubernetes-in-action)*: the best book we’ve found for getting up
  and running with Kubernetes.

### Repo organization

- [modules](/modules): the main implementation code for this repo, broken down into multiple standalone, orthogonal submodules.
- [examples](/examples): This folder contains working examples of how to use the submodules.
- [test](/test): Automated tests for the modules and examples.

## Deploy

### Non-production deployment (quick start for learning)

If you just want to try this repo out for experimenting and learning, check out the following resources:

- [examples/for-learning-and-testing folder](/examples/for-learning-and-testing): The
  `examples/for-learning-and-testing` folder contains standalone sample code optimized for learning, experimenting, and
  testing (but not direct production usage).

### Production deployment

If you want to deploy this repo in production, check out the following resources:

- [examples/for-production folder](/examples/for-production): The `examples/for-production` folder contains sample code
  optimized for direct usage in production. This is code from the
  [Gruntwork Reference Architecture](https://gruntwork.io/reference-architecture), and it shows you how we build an
  end-to-end, integrated tech stack on top of the Gruntwork Service Catalog.

## Operate

- [How do I assign IAM permissions to a service?](core-concepts.md#how-do-i-assign-iam-permissions-to-a-service)

## Support

If you need help with this repo, [post a question in our knowledge base](https://github.com/gruntwork-io/knowledge-base/discussions?discussions_q=label%3Ar%3Aterraform-aws-service-catalog)
or [reach out via our support channels](https://docs.gruntwork.io/support) included with your subscription. If you’re
not yet a Gruntwork subscriber, [subscribe now](https://www.gruntwork.io/pricing/).

## Contributions

Contributions to this repo are both welcome and appreciated! If you fix a bug, add a new feature, or even wish to
contribute an entirely new module, we’re happy to accept pull requests, provide feedback, and run your changes
through our automated test suite.
See our [contribution guide](https://docs.gruntwork.io/guides/working-with-code/contributing) for instructions.

## License

Please see [LICENSE.txt](/LICENSE.txt) for details on how the code in this repo is licensed.
