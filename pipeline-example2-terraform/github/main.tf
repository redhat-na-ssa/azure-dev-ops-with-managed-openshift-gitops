resource "github_repository" "repo" {
  name         = "azure-dev-ops-with-managed-openshift-gitops"
  description  = "Azure GitOps Example Repository "
  visibility   = "public"
  lifecycle {
    ignore_changes = [
      all,
    ]
    prevent_destroy = true
  }
}

resource "github_repository_webhook" "azdevops_webhook" {
  repository = github_repository.repo.name

  configuration {
    url          = "https://google.de/"
    content_type = "form"
    insecure_ssl = false
  }

  active = false

  events = ["issues"]
}
