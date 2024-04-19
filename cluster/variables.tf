variable "cluster_name" {
  type        = string
  description = "name of the cluster"
}

variable "cluster_version" {
  type        = string
  description = "cluster version"
}

variable "vpc_id" {
  type        = string
  description = "ID for VPC"
}

variable "subnet_ids" {
  type = list
}

variable "control_plane_subnet_ids" {
  type = list
}

variable "tags" {
  type        = map
  description = "tags to identify resources"
}
