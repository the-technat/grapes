locals {
  ingress_nginx_name = "ingress-nginx"
  ingress_class      = "nginx"
}

resource "kubernetes_namespace_v1" "ingress_nginx" {
  metadata {
    name = local.ingress_nginx_name
  }
  depends_on = [module.eks]
}

resource "helm_release" "ingress_nginx" {
  name       = local.ingress_nginx_name
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.11.2"
  timeout    = 900
  namespace  = kubernetes_namespace_v1.ingress_nginx.metadata[0].name

  values = [
    templatefile("${path.module}/helm_values/ingress_nginx.yaml", {
      class = local.ingress_class
    })
  ]

  depends_on = [
    helm_release.cluster_autoscaler,
    helm_release.external_dns,
    helm_release.cert_manager,
    helm_release.aws_load_balancer_controller,
  ]
}