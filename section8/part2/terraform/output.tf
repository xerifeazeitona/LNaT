output "ips" {
  value = libvirt_domain.machine.*.network_interface.0.addresses
}

output "names" {
  value = libvirt_domain.machine.*.name
}