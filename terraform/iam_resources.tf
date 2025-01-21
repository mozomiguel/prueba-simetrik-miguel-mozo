# Create iam role for codepipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "codepipeline-role-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codepipeline.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "codebuild-inline-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "codebuild:StartBuild",
            "codebuild:StopBuild",
            "codebuild:BatchGetBuilds",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "codestar-connections:UseConnection"
          ]
          Effect   = "Allow"
          Resource = var.connection_arn
        },
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
  tags = local.tags
}
# Create iam policy for load balancer controller
resource "aws_iam_policy" "aws_load_balancer_controller" {
  name        = "AWSLoadBalancerControllerIAMPolicy"
  description = "Policy for AWS Load Balancer Controller"

  policy = jsonencode({
    "Statement": [
        {
            "Action": "iam:CreateServiceLinkedRole",
            "Condition": {
                "StringEquals": {
                    "iam:AWSServiceName": "elasticloadbalancing.amazonaws.com"
                }
            },
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetGroupAttributes",
                "elasticloadbalancing:DescribeTags",
                "elasticloadbalancing:DescribeSSLPolicies",
                "elasticloadbalancing:DescribeRules",
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeLoadBalancerAttributes",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeListenerAttributes",
                "elasticloadbalancing:DescribeListenerCertificates",
                "ec2:GetCoipPoolUsage",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DescribeTags",
                "ec2:DescribeSubnets",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeNetworkInterfaces",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeInstances",
                "ec2:DescribeCoipPools",
                "ec2:DescribeAvailabilityZones",
                "ec2:DescribeAddresses",
                "ec2:DescribeAccountAttributes"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "wafv2:GetWebACLForResource",
                "wafv2:GetWebACL",
                "wafv2:DisassociateWebACL",
                "wafv2:AssociateWebACL",
                "waf-regional:GetWebACLForResource",
                "waf-regional:GetWebACL",
                "waf-regional:DisassociateWebACL",
                "waf-regional:AssociateWebACL",
                "shield:GetSubscriptionState",
                "shield:DescribeProtection",
                "shield:DeleteProtection",
                "shield:CreateProtection",
                "iam:ListServerCertificates",
                "iam:GetServerCertificate",
                "cognito-idp:DescribeUserPoolClient",
                "acm:ListCertificates",
                "acm:DescribeCertificate"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "ec2:RevokeSecurityGroupIngress",
                "ec2:CreateSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": "ec2:CreateTags",
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                },
                "StringEquals": {
                    "ec2:CreateAction": "CreateSecurityGroup"
                }
            },
            "Effect": "Allow",
            "Resource": "arn:aws:ec2:*:*:security-group/*"
        },
        {
            "Action": [
                "ec2:DeleteTags",
                "ec2:CreateTags"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "true",
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            },
            "Effect": "Allow",
            "Resource": "arn:aws:ec2:*:*:security-group/*"
        },
        {
            "Action": [
                "ec2:RevokeSecurityGroupIngress",
                "ec2:DeleteSecurityGroup",
                "ec2:AuthorizeSecurityGroupIngress"
            ],
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            },
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "elasticloadbalancing:CreateTargetGroup",
                "elasticloadbalancing:CreateLoadBalancer"
            ],
            "Condition": {
                "Null": {
                    "aws:RequestTag/elbv2.k8s.aws/cluster": "false"
                }
            },
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "elasticloadbalancing:DeleteRule",
                "elasticloadbalancing:DeleteListener",
                "elasticloadbalancing:CreateRule",
                "elasticloadbalancing:CreateListener"
            ],
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "elasticloadbalancing:RemoveTags",
                "elasticloadbalancing:AddTags"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/net/*/*",
                "arn:aws:elasticloadbalancing:*:*:loadbalancer/app/*/*"
            ]
        },
        {
            "Action": [
                "elasticloadbalancing:RemoveTags",
                "elasticloadbalancing:AddTags"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:elasticloadbalancing:*:*:listener/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener/app/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/net/*/*/*",
                "arn:aws:elasticloadbalancing:*:*:listener-rule/app/*/*/*"
            ]
        },
        {
            "Action": [
                "elasticloadbalancing:SetSubnets",
                "elasticloadbalancing:SetSecurityGroups",
                "elasticloadbalancing:SetIpAddressType",
                "elasticloadbalancing:ModifyTargetGroupAttributes",
                "elasticloadbalancing:ModifyTargetGroup",
                "elasticloadbalancing:ModifyLoadBalancerAttributes",
                "elasticloadbalancing:DeleteTargetGroup",
                "elasticloadbalancing:DeleteLoadBalancer"
            ],
            "Condition": {
                "Null": {
                    "aws:ResourceTag/elbv2.k8s.aws/cluster": "false"
                }
            },
            "Effect": "Allow",
            "Resource": "*"
        },
        {
            "Action": [
                "elasticloadbalancing:RegisterTargets",
                "elasticloadbalancing:DeregisterTargets"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:elasticloadbalancing:*:*:targetgroup/*/*"
        },
        {
            "Action": [
                "elasticloadbalancing:SetWebAcl",
                "elasticloadbalancing:RemoveListenerCertificates",
                "elasticloadbalancing:ModifyRule",
                "elasticloadbalancing:ModifyListener",
                "elasticloadbalancing:AddListenerCertificates"
            ],
            "Effect": "Allow",
            "Resource": "*"
        }
    ],
    "Version": "2012-10-17"
  })
}
# Create iam role for codebuild build phase
resource "aws_iam_role" "build_role" {
  name = "codebuild-role-build-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"

        }
      },
    ]
  })
  inline_policy {
    name = "codebuild-inline-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect   = "Allow"
          Resource = "*"
        },        
        { 
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters"
            ],
            "Resource": "*"
        },
        {
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
      ]
    })
  }
  tags = local.tags
}
# Create iam role for codebuild deploy phase
resource "aws_iam_role" "deployment_role" {
  name = "codebuild-role-deployment-${var.cluster_name}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "codebuild.amazonaws.com"
        }
      },
    ]
  })
  inline_policy {
    name = "codebuild-inline-policy"
    policy = jsonencode({
      Version = "2012-10-17"
      Statement = [
        {
          Action = [
            "ecr:BatchCheckLayerAvailability",
            "ecr:CompleteLayerUpload",
            "ecr:GetAuthorizationToken",
            "ecr:InitiateLayerUpload",
            "ecr:PutImage",
            "ecr:UploadLayerPart",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        { 
            "Effect": "Allow",
            "Action": [
                "eks:DescribeCluster",
                "eks:ListClusters",
                "eks:AccessKubernetesApi"
            ],
            "Resource": "*"
        },
        {
          Action = [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
          Action = [
            "s3:ListBucket",
            "s3:PutObject",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:GetBucketAcl",
            "s3:GetBucketLocation",
          ]
          Effect   = "Allow"
          Resource = "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:DescribeLoadBalancers",
                "elasticloadbalancing:DescribeTargetGroups",
                "elasticloadbalancing:DescribeTargetHealth",
                "elasticloadbalancing:DescribeListeners",
                "elasticloadbalancing:DescribeTags"
            ],
            "Resource": "*"
        },

      ]
    })
  }
  tags = local.tags
}