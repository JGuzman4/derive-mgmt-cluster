module "eks_managed_node_group" {
  source  = "terraform-aws-modules/eks/aws//modules/eks-managed-node-group"
  version = "19.10.0"

  name            = "separate"
  cluster_name    = var.cluster_name # module.eks.cluster_name
  cluster_version = var.cluster_version # module.eks.cluster_version

  subnet_ids = var.subnet_ids # module.vpc.private_subnets
  vpc_security_group_ids = [
    module.eks.cluster_primary_security_group_id,
    module.eks.cluster_security_group_id,
  ]

  create_iam_role = false
  iam_role_arn    = aws_iam_role.this.arn

  min_size     = 1
  max_size     = 3
  desired_size = 1

  tags = var.tags
}
