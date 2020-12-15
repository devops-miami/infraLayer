output "name" {
    value = {for r in  google_container_cluster.default: r.name => r.name}
}

output "endpoint" {
    value = {for r in  google_container_cluster.default: r.name => r.endpoint}
}
