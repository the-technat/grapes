locals {
  cert_manager_name = "cert-manager"
}
resource "kubernetes_namespace_v1" "cert_manager" {
  metadata {
    name = local.cert_manager_name
  }
  depends_on = [module.eks]
}


resource "helm_release" "cert_manager" {
  name       = local.cert_manager_name
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.15.3"
  namespace  = kubernetes_namespace_v1.cert_manager.metadata[0].name

  values = [
    templatefile("${path.module}/helm_values/cert_manager.yaml", {
      rolearn = module.cert_manager_dns_01_irsa.iam_role_arn
    })
  ]

  depends_on = [
    helm_release.cluster_autoscaler,
    helm_release.aws_load_balancer_controller,
  ]
}

# Deploys the issuers
resource "helm_release" "cert_manager_extras" {
  name      = "cert-manager-extras"
  chart     = "${path.module}/charts/cert-manager-extras"
  namespace = local.cert_manager_name

  values = [
    templatefile("${path.module}/helm_values/cert_manager_extras.yaml", {
      email  = var.email
      region = var.region
      zoneid = aws_route53_zone.primary.zone_id
    })
  ]

  depends_on = [
    helm_release.cert_manager,
    module.cert_manager_dns_01_irsa,
  ]
}


module "cert_manager_dns_01_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.44.1"

  role_name_prefix           = "cert-manager"
  attach_cert_manager_policy = true

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["${local.cert_manager_name}:${local.cert_manager_name}"]
    }
  }

  tags = var.tags
}