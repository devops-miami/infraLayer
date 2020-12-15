# Demo for using Terraform 
# devops.miami by Rick Alvarez
##
module gke-cluster {
    source          = "../modules/google_container_cluster"
    clusters        =  var.clusters
}
