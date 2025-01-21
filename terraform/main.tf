# Create the local tags and variables and variables to use in vpc
locals {
  tags = {
    created-by = "prueba_simetrik_miguel_mozo"
    env        = var.cluster_name
  }
  private_subnets = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k + 3)]
  public_subnets  = [for k, v in local.azs : cidrsubnet(var.vpc_cidr, 3, k)]
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
}
# Get the the data for the available azs in the default region
data "aws_availability_zones" "available" {
  state = "available"
}
# Get the credentials for aws config
data "aws_caller_identity" "current" {}

# Create the VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.1"

  name = var.cluster_name
  cidr = var.vpc_cidr

  azs                   = local.azs
  public_subnets        = local.public_subnets
  private_subnets       = local.private_subnets
  public_subnet_suffix  = "SubnetPublic"
  private_subnet_suffix = "SubnetPrivate"

  enable_nat_gateway   = true
  create_igw           = true
  enable_dns_hostnames = true
  single_nat_gateway   = true

  manage_default_network_acl    = true
  default_network_acl_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_route_table    = true
  default_route_table_tags      = { Name = "${var.cluster_name}-default" }
  manage_default_security_group = true
  default_security_group_tags   = { Name = "${var.cluster_name}-default" }

  public_subnet_tags = merge(local.tags, {
    "kubernetes.io/role/elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  })
  private_subnet_tags = merge(local.tags, {
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.cluster_name}"  = "shared"
  })

  tags = local.tags
}

# Create EKS cluster
module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name                             = var.cluster_name
  cluster_version                          = var.cluster_version
  cluster_endpoint_public_access           = true
  enable_cluster_creator_admin_permissions = true
  enable_irsa = true

  cluster_addons = {

    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      before_compute = true
      most_recent    = true
      configuration_values = jsonencode({
        env = {
          ENABLE_POD_ENI                    = "true"
          ENABLE_PREFIX_DELEGATION          = "true"
          POD_SECURITY_GROUP_ENFORCING_MODE = "standard"
        }
        nodeAgent = {
          enablePolicyEventLogs = "true"
        }
        enableNetworkPolicy = "true"
      })
    }
  }

  vpc_id     = module.vpc.vpc_id #Use the vpc created
  subnet_ids = module.vpc.private_subnets

  create_cluster_security_group = false
  create_node_security_group    = false

  eks_managed_node_groups = {
    default = {
      instance_types           = ["t3.small"]
      force_update_version     = true
      release_version          = var.ami_release_version
      use_name_prefix          = false
      iam_role_name            = "${var.cluster_name}-ng-default"
      iam_role_use_name_prefix = false

      min_size     = 1
      max_size     = 4
      desired_size = 3

      update_config = {
        max_unavailable_percentage = 50
      }

      labels = {
        default = "yes"
      }
    }
  }

  tags = merge(local.tags, {
    "kubernetes.io/cluster/${var.cluster_name}" = "owned"
  })
}

# ADD THE LOAD BALANCER CONTROLER TO THE EKS CLUSTER
# Create the role for the load balancer controller and ensure the service account can asum it
module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "5.3.0"

  role_name = "aws-load-balancer-controller"
  role_policy_arns = {
    policy = aws_iam_policy.aws_load_balancer_controller.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }
}
# Create the service account for the load balancer controller
resource "kubernetes_service_account" "service-account" {
  metadata {
    name = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = module.lb_role.iam_role_arn
    }
  }
}
# Deploy the load balancer controller in the eks cluster using helm
resource "helm_release" "lb" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [
    kubernetes_service_account.service-account
  ]

  set {
    name  = "region"
    value = var.aws_region
  }

  set {
    name  = "vpcId"
    value = module.vpc.vpc_id
  }

  set {
    name  = "image.repository"
    value = "602401143452.dkr.ecr.${var.aws_region}.amazonaws.com/amazon/aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.create"
    value = "false"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "clusterName"
    value = var.cluster_name
  }
}

# BUILD AND DEPLOYMENT FOR THE APP IN THE EKS CLUSTER
# Create S3 bucket to save code pipeline artifacts
module "s3_bucket" {
  source  = "terraform-aws-modules/s3-bucket/aws"
  version = "~> 3.0"

  bucket_prefix = "code-artifacts-${var.cluster_name}"

  versioning = {
    status = true
  }

  tags = local.tags
}
# create ECR repo to push the app images
resource "aws_ecr_repository" "ecr_repo" {
  name = "image-repo-${var.cluster_name}"
  tags = local.tags
}
# Map the deployment role to kubernetes cluster so it can deploy the k8s resources  
resource "kubernetes_config_map_v1_data" "aws_auth" {
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(concat(
      [
        {
          rolearn  = aws_iam_role.deployment_role.arn
          username = "codebuild"
          groups   = ["system:masters"]
        }
      ]
    ))
  }

  force = true

  depends_on = [
    module.eks
  ]
}
# Create a pipeline to build the app and deploy in EKS
resource "aws_codepipeline" "pipeline" {
  name     = "pipeline-${var.cluster_name}"
  role_arn = aws_iam_role.codepipeline_role.arn
  tags     = local.tags

  artifact_store {
    location = module.s3_bucket.s3_bucket_id # Here we define store the artifacts in the created s3 bucket
    type     = "S3"
  }
  stage { # Stage for get the source code from github
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = [
        "source_output",
      ]

      configuration = {
        ConnectionArn    = var.connection_arn
        FullRepositoryId = "mozomiguel/prueba-simetrik-mamr"
        BranchName       = "master"
      }
    }
  }
  stage { # Stage for build the app and push the images to ECR
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = [
        "source_output",
      ]
      output_artifacts = [
        "build_output",
      ]
      version          = "1"

      configuration = {
        ProjectName = "build-${var.cluster_name}"      
      } 
    }
  }
  stage { # Stage for deploy the app in the EKS cluster
    name = "Deploy"
    action {
      name            = "Deploy"
      category        = "Build"
      owner           = "AWS"
      provider        = "CodeBuild"
      input_artifacts = [
        "source_output",
      ]
      version = "1"

      configuration = {
        ProjectName = "deploy-to-eks-${var.cluster_name}"
      }
    }
  }
}
# Create the codebuild project to build the app
resource "aws_codebuild_project" "build" {
  name         = "build-${var.cluster_name}"
  service_role = aws_iam_role.build_role.arn
  artifacts {
    type = "CODEPIPELINE"
  }
  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image        = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type         = "LINUX_CONTAINER"
    environment_variable {
      name  = "ECR_REPO"
      value = aws_ecr_repository.ecr_repo.repository_url
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
  }
  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yaml"
  }
  tags = local.tags
}
# Create a codebuild project to deploy the app in the EKS cluster
resource "aws_codebuild_project" "deploy" {
  name          = "deploy-to-eks-${var.cluster_name}"
  service_role  = aws_iam_role.deployment_role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                      = "aws/codebuild/amazonlinux2-x86_64-standard:4.0"
    type                       = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode            = true

    environment_variable {
      name  = "ECR_REPO"
      value = aws_ecr_repository.ecr_repo.repository_url
    }
    environment_variable {
      name  = "AWS_ACCOUNT_ID"
      value = data.aws_caller_identity.current.account_id
    }
    environment_variable { # load the cluster name to deploy the app
      name  = "CLUSTER_NAME"
      value = var.cluster_name
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec-deploy.yaml"
  }
}