module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.10.0"

  cluster_name                   = var.cluster_name
  cluster_version                = var.cluster_version
  cluster_endpoint_public_access = true

  vpc_id                   = var.vpc_id # module.vpc.vpc_id
  subnet_ids               = var.subnet_ids # module.vpc.private_subnets
  control_plane_subnet_ids = var.control_plane_subnet_ids  # module.vpc.intra_subnets
  tags                     = var.tags # local.tags
}
