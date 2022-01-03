# Copyright (C) 2021 Nicolas Lamirault <nicolas.lamirault@gmail.com>

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

data "aws_iam_policy_document" "kms" {
  count = var.enable_kms ? 1 : 0

  statement {
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:GenerateDataKey*",
    ]

    resources = [
      aws_kms_key.teleport[0].arn
    ]
  }
}

resource "aws_iam_policy" "kms" {
  count = var.enable_kms ? 1 : 0

  name        = local.service_name
  path        = "/"
  description = "Permissions for Teleport"
  policy      = data.aws_iam_policy_document.kms[0].json
  tags = merge(
    { "Name" = format("%s-kms", local.service_name) },
    local.tags
  )
}

resource "aws_iam_policy" "dynamodb" {
  name        = format("%sDynamoDBPolicy", title(local.role_name))
  description = format("Allow Teleport to manage AWS DynamoDB resources")
  path        = "/"
  #tfsec:ignore:AWS099
  policy = file("${path.module}/dynamodb_policy.json")
  tags   = var.tags
}

resource "aws_iam_policy" "s3" {
  name        = format("%sS3Policy", title(local.role_name))
  description = format("Allow Teleport to manage AWS S3 resources")
  path        = "/"
  #tfsec:ignore:AWS099
  policy = file("${path.module}/s3_policy.json")
  tags   = var.tags
}

resource "aws_iam_policy" "dns" {
  name        = format("%sRoute53Policy", title(local.role_name))
  description = format("Allow Teleport to manage AWS Route53 resources")
  path        = "/"
  #tfsec:ignore:AWS099
  policy = file("${path.module}/route53_policy.json")
  tags   = var.tags
}

module "teleport_role" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "4.8.0"

  create_role      = true
  role_description = "Teleport Role"
  role_name        = local.role_name
  provider_url     = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
  role_policy_arns = var.enable_kms ? [
    aws_iam_policy.kms[0].arn,
    aws_iam_policy.dynamodb.arn,
    aws_iam_policy.s3.arn,
    aws_iam_policy.dns.arn
    ] : [
    aws_iam_policy.dynamodb.arn,
    aws_iam_policy.s3.arn,
    aws_iam_policy.dns.arn
  ]
  oidc_fully_qualified_subjects = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
  tags = merge(
    { "Name" = local.role_name },
    local.tags
  )
}
