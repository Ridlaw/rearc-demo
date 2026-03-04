output "cluster_name" {
  value = module.eks.cluster_name
}

output "configure_kubectl" {
  value = "aws eks update-kubeconfig --region ${var.aws_region} --name ${module.eks.cluster_name}"
}

output "acm_cert_arn" {
  value = aws_acm_certificate.selfsigned.arn
}

# Ingress hostname (ALB DNS) – will populate after controller provisions ALB
output "alb_hostname" {
  value = try(kubernetes_ingress_v1.app.status[0].load_balancer[0].ingress[0].hostname, "")
}