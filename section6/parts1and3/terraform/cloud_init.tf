data "template_file" "user_data" {
  count    = length(var.machine_name)
  template = file("${path.module}/cloud_init.cfg")
  vars = {
    hostname = element(var.machine_name, count.index)
  }
}

data "template_file" "network_config" {
  template = file("${path.module}/network_config.cfg")
}

resource "libvirt_cloudinit_disk" "commoninit" {
  count          = length(var.machine_name)
  name           = "${var.machine_name[count.index]}-commoninit.iso"
  pool           = var.volume_pool
  user_data      = data.template_file.user_data[count.index].rendered
  network_config = data.template_file.network_config.rendered
}