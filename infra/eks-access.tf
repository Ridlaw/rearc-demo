

resource "aws_eks_access_entry" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.eks_admin_principal_arn

  depends_on = [module.eks]
}

resource "aws_eks_access_policy_association" "admin" {
  cluster_name  = module.eks.cluster_name
  principal_arn = var.eks_admin_principal_arn
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }

  depends_on = [aws_eks_access_entry.admin]
}