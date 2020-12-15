# Clusters
variable "clusters" {
    type = map
    default = {
        test-cluster = {
            location = "us-east1"
            issue_cert = "true"
            node_locations = [ "us-east1-b", "us-east1-d" ]
            tags = [ "demo", "poc"]
            labels = "poc"
        }
    }
}
