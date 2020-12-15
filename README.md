# Infrastructure Layer
This layer is responsible for provisioning resources on the cloud we can use in the other layers. The folder structure is documented below and will get more complex the further you go.
Disclaimer: A highly opinionated take on running `Terraform`.
If you are provisioning one resource this is overkill but if you need to maintain a large complex system which is going to grow over time this makes a bit easier to handle. I use this for an SFTP system and as you can imagine there is a ton of variables to keep track up primarily ssh-keys and users. This pattern works really well for this use case but make sure to apply it only when needed.
*The pattern we use here makes it so that daily changes like adding a user or new instance happens in the values file and not the main code base(DRY). Splitting this up makes it to we can test the exact same code between environments like poc and prod*

## Base files
Some of default setup.
```sh
mkdir project # this folder will contain the main.tf and be the start point
mkdir modules # all of our custom modules go here
touch project/main.tf # where tf apply starts
touch project/vars.tf # the variables we are going to pass to our terraform
touch project/README.md # document what you build
touch project/output.tf # what we need to output at the end of it all
touch project/providers.tf # how we connect to the places we are deploying too
```

## Building the First Module
Custom modules really aren't popular. People like to just reference the resource directly on the internet and be done with it. That's cool but doesn't support `for_each` and dependencies nicely. I like to have all my values in maps and still maintain dependencies between resources I am provisioning. The idea is I keep a minimualistic `main.tf` that makes it easy to see the types of resources being deployed and their dependencies to each other. The `vars.tf` file keeps a list of all the things we are actually provisioning and their values. To accomplish this we use `lookup()` and our `output.tf` files create maps for us to use. When to use this setup is important to note. 

* Keep modules DRY
* Reuseable modules (we use null and if statements when needed)
* for_each - Iterate for new resources, 

If you don't know much about `Terraform` and this is your first rodeo you'll want to start at `Google Search` with something like thing you want to create + Terraform + cloud provider. Let's try a `GKE` cluster on Google Cloud.  

[Terraform Google Container Cluster Resource](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/container_cluster)

Create the files we need to work with.
```sh
mkdir google_container_cluster # folder containing a single resource
touch main.tf # resource
touch vars.tf # variables we can pass to the resource
touch output.tf # the output of this module
```

Copy pasta the resource you are trying to create from the Terraform page. This block says you want to create a `google_container_cluster`. 
In this example we want to create the `GKE` cluster and its `node pool` in different modules.
```sh
resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"

  location = "us-central1"
  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = false
    }
  }
}
```

Create a variables file, this file will contain the structure of the expected variables we can pass to this module. 
If you don't pass a variable in the module it will default to what you put here. 

*There are many different variables types make sure to research this on your own.*

The way I like to set things with maps, it looks like the following:
```sh
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
```

The first key is the name of the cluster. In this case `test-cluster` and it's settings will be pulled from its contained key value pairs. The maps are typically created by modifying a resource and extracting the hard coded values out two layers to `/project/vars.tf`

Adding the for_each is where the module begins to get variablized.
```sh
resource "google_container_cluster" "primary" {

  for_each = var.clusters # this line tells the resource we want to iterate for every item in the map

  name     = each.value.name # as the system iterates each name from the respective map will be used
  location = each.value.location

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  master_auth {
    username = ""
    password = ""

    client_certificate_config {
      issue_client_certificate = each.value.issue_cert
    }
  }
}
```

When we run this module it will iterate on the map and create a cluster with the correct values. Once that is done the module will need to output the name and endpoint for the cluster.
Create an output.tf with the following settings.
```sh
output "name" {
  value = {for r in  google_container_cluster.default: r.name => r.name}
}

output "endpoint" {
  value = {for r in  google_container_cluster.default: r.name => r.endpoint}
}
```

This output will help us establish our dependency for the `container_node_pool` using `lookup()`.

## Building the Main Project
The starting point in `Terraform` is the directory you run `terraform apply` from called the root directory. In this case it is called `project` and this folder will contain the three files we use the most in `Terraform`. Edit `project/main.tf` to have a reference to the custom module we just created.

The code is kept dry by passing variables to the `main.tf` which in turn passes it to the modules. When we want to provision different infrastructure we can reference a different variables file like `prod-vars.tf`.

Add the map for clusters, it should look like this
```sh
# Clusters
variable "clusters" {
    type = map
    default = {
        blog-cluster = {
            location = "us-east1-c"
            issue_cert = "false"
            zone = "us-east1-c"
            node_locations = [ "us-east1-b", "us-east1-d" ]
            labels = "prod"
            tags = ["bloggerbob", "poc"]
            machine_type = "n1-standard-1"
        }
    }
}
```