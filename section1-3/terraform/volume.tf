resource "libvirt_volume" "os_image" {
  source = var.os_image_path
  name   = "os_image"
  pool = var.volume_pool
  format = "qcow2"
}

resource "libvirt_volume" "os_disk" {
  count          = length(var.machine_name)
  name           = "${var.machine_name[count.index]}_os_disk"
  pool           = var.volume_pool
  base_volume_id = libvirt_volume.os_image.id
  size           = var.disk_size
}