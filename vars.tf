# Clusters
variable "clusters" {
    type = map
    default = {
        blog-cluster = {
            location = "us-east1-c"
            issue_cert = "false"
        }
    }
}
