
#Set Variables
variable "KUBE_CONFIG_PATH" {
  type = string
  default = "~/.kube/config"
}

variable "AZP_URL" {
  type = string
}

variable "AZP_TOKEN" {
  type      = string
  sensitive = true
}

variable "AZP_POOL" {
  type = string
}

variable "PIPELINE_NAMESPACE" {
  type = string
  default = "ado-openshift"
}

variable "BUILD_NAMESPACE" {
  type = string
  default = "azure-build"
}

variable "BUILD_SERVICEACCOUNT_NAME" {
  type = string
  default = "azure-build-agent-openshift-sa"
}

variable "PIPELINE_SERVICEACCOUNT_NAME" {
  type = string
  default = "azure-sa"
}

variable "PIPELINE_SECRETNAME" {
  type = string
  default = "azure-sa-devops-secret"
}

variable "IMAGEREGISTRY_ROUTE_NAME" {
  type = string
  default = "default-route"
}

variable "IMAGEREGISTRY_ROUTE_NAMESPACE" {
  type = string
  default = "openshift-image-registry"
}


#Create Azure Agent Build via Helm
resource "helm_release" "azure-build-agent-openshift" {
  name             = "azure-build-agent-openshift"
  chart            = "../charts/azure-build-agent-openshift"
  create_namespace = "true"
  namespace        = "${var.BUILD_NAMESPACE}"
  wait = "true"

  set {
    name  = "azp_url"
    value = var.AZP_URL
  }

  set {
    name  = "azp_token"
    value = var.AZP_TOKEN
  }

  set {
    name  = "azp_pool"
    value = var.AZP_POOL
  }

  set {
    name = "serviceAccount.name"
    value = var.BUILD_SERVICEACCOUNT_NAME
  }

}

#Create Azure Pipeline Info in OCP via Helm
resource "helm_release" "azure-pipeline" {
  depends_on = [helm_release.azure-build-agent-openshift]
  name             = "azure-devops-pipeline"
  chart            = "../charts/azure-devops-pipeline"
  create_namespace = "true"
  namespace        = "${var.PIPELINE_NAMESPACE}"
  wait = "true"

  set {
    name = "serviceAccount.name"
    value = var.PIPELINE_SERVICEACCOUNT_NAME
  }

  set {
    name = "serviceAccount.secretname"
    value = var.PIPELINE_SECRETNAME
  }

  set {
    name = "buildNamespace"
    value = var.BUILD_NAMESPACE
  }

}

#Get ImageRegistry Route(Will move to providers in the next version)
data "external" "imageregistry_route" {
  program = ["bash", "${path.module}/get-default-hostname.sh"]

  query = {
    namespace = var.IMAGEREGISTRY_ROUTE_NAMESPACE
    routename = var.IMAGEREGISTRY_ROUTE_NAME
  }
}


#Get Secret(Will move to providers in the next version)
data "external" "sa_secret" {
  depends_on = [helm_release.azure-pipeline]
  program = ["bash", "${path.module}/get-secret-token.sh"]

  query = {
    namespace = var.PIPELINE_NAMESPACE
    secretname = var.PIPELINE_SECRETNAME
  }
}

#Get Cluster Server Address(Will move to providers in the next version)
data "external" "server_url" {
  depends_on = [helm_release.azure-pipeline]
  program = ["bash", "${path.module}/get-server-info.sh"]

}

# Create an Azure DevOps Project
resource "azuredevops_project" "azure-devops-pipeline" {
  name       = "AzureDevOpsPipeline"
  visibility = "private"
}

#Create an OpenShift Registry Service Connection
resource "azuredevops_serviceendpoint_dockerregistry" "openshift-registry" {
  project_id            = azuredevops_project.azure-devops-pipeline.id
  service_endpoint_name = "openshift-registry"  
  docker_registry = chomp(format("%s://%s","https",base64decode(data.external.imageregistry_route.result.encoded_route)))
  docker_username            = "${var.PIPELINE_SERVICEACCOUNT_NAME}"
  docker_password            = chomp(data.external.sa_secret.result.encoded_secret)
  registry_type = "Others"
  description = "OpenShift Pipeline Registry Service Connection"
}

resource "azuredevops_serviceendpoint_kubernetes" "openshift-service-endpoint" {
  project_id            = azuredevops_project.azure-devops-pipeline.id
  service_endpoint_name = "openshift"
  apiserver_url         = chomp(base64decode(data.external.server_url.result.encoded_apiserver))
  authorization_type    = "Kubeconfig"

  kubeconfig {
    kube_config            = file("~/.kube/config")
    accept_untrusted_certs = true
  }
}

resource "azuredevops_serviceendpoint_github" "gitops-connection" {
  project_id            = azuredevops_project.azure-devops-pipeline.id
  service_endpoint_name = "GitOps Connection"
  auth_personal {
    personal_access_token = ""
  }
}

resource "azuredevops_build_definition" "azuredevops_build_definition" {
  project_id = azuredevops_project.azure-devops-pipeline.id
  name       = "OpenShift Pipeline Example"

  repository {
    repo_type             = "GitHub"
    repo_id               = "MoOyeg/azure-pipelines-openshift"
    branch_name           = "main"
    yml_path              = "azure-pipelines.yml"
    service_connection_id = azuredevops_serviceendpoint_github.gitops-connection.id
  }
}

resource "azuredevops_agent_pool" "azuredevops_agent_pool" {
  name           = var.AZP_POOL
  auto_provision = false
  auto_update    = false
}

resource "azuredevops_agent_queue" "azuredevops_agent_queue" {
  project_id    = azuredevops_project.azure-devops-pipeline.id
  agent_pool_id = azuredevops_agent_pool.azuredevops_agent_pool.id
}

resource "azuredevops_pipeline_authorization" "azuredevops_pipeline_authorization_queue" {
  project_id  = azuredevops_project.azure-devops-pipeline.id
  resource_id = azuredevops_agent_queue.azuredevops_agent_queue.id
  type        = "queue"
  pipeline_id = azuredevops_build_definition.azuredevops_build_definition.id
}

resource "azuredevops_pipeline_authorization" "azuredevops_pipeline_authorization_endpoint_gitops" {
  project_id  = azuredevops_project.azure-devops-pipeline.id
  resource_id = azuredevops_serviceendpoint_github.gitops-connection.id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.azuredevops_build_definition.id
}

resource "azuredevops_pipeline_authorization" "azuredevops_pipeline_authorization_endpoint_registry" {
  project_id  = azuredevops_project.azure-devops-pipeline.id
  resource_id = azuredevops_serviceendpoint_dockerregistry.openshift-registry.id
  type        = "endpoint"
  pipeline_id = azuredevops_build_definition.azuredevops_build_definition.id
}


output "ca_object" {
  value = data.external.sa_secret.result.encoded_ca
}

output "token_object" {
  value = data.external.sa_secret.result.encoded_secret
}
