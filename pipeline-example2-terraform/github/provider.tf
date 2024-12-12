terraform {
  required_providers {
    azuredevops = {
      source  = "microsoft/azuredevops"
      version = "1.4.0"
    }
    github = {
      source  = "integrations/github"
      version = "6.4.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.34.0"
    }
    external = {
      source = "hashicorp/external"
      version = "2.3.4"
    }
  }
}
