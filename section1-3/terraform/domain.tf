resource "libvirt_domain" "machine" {
  count  = length(var.machine_name)
  name   = var.machine_name[count.index]
  vcpu   = var.vcpu
  memory = var.memory
  qemu_agent = true

  cloudinit = libvirt_cloudinit_disk.commoninit[count.index].id

  disk {
    volume_id = element(libvirt_volume.os_disk.*.id, count.index)
  }

  network_interface {
    network_name = var.network
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  console {
    type        = "pty"
    target_type = "virtio"
    target_port = "1"
  }

  graphics {
    type        = "spice"
    listen_type = "address"
    autoport    = true
  }

}