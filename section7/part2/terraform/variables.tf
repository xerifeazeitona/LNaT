# The connection URI used to connect to the libvirt host
variable "qemu_uri" {
    default = "qemu:///system"
}

# The storage pool where the resource will be created
variable "volume_pool" {
    default = "default"
}

# The size of the volume in bytes
variable "disk_size" { 
    #1024*1024*1024 = 1G
    default = 1024*1024*1024*10
}

# It's possible to specify the path to a local image or a remote(HTTP(S) url) one
variable "os_image_path" {}

# The name of an existing network to attach this interface to
variable "network" {
    default = "default"
}

# A unique name for the virtual machine
variable "machine_name" {
    type = list(string)
    default = ["dummy_vm"]
}

# The amount of virtual CPUs
variable "vcpu" {
    default = "1"
 }

# The amount of memory in MiB
variable "memory" {
    default = "512"
}