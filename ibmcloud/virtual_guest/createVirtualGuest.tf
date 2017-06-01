variable "hostname" {}
variable "datacenter" {}
variable "user_public_key_id" {}
variable "temp_public_key_id" {}
variable "temp_public_key" {}
variable "temp_private_key" {}
variable "module_script" {
  default = "files/default.sh"	
}
variable "os_reference_code" {}
variable "domain" {}
variable "cores" {}
variable "memory" {}
variable "disk1" {}
variable "ssh_user" {
  default = "root"
}
variable "module_custom_commands" {
  default = "sleep 1"
}
variable "remove_temp_private_key" {
  default = "true"
}

resource "ibmcloud_infra_virtual_guest" "softlayer_virtual_guest" {
  hostname                 = "${var.hostname}"
  os_reference_code        = "${var.os_reference_code}"
  domain                   = "${var.domain}"
  datacenter               = "${var.datacenter}"
  network_speed            = 10
  hourly_billing           = true
  private_network_only     = false
  cores                    = "${var.cores}"
  memory                   = "${var.memory}"
  disks                    = ["${var.disk1}"]
  dedicated_acct_host_only = true
  local_disk               = false
  ssh_key_ids              = ["${var.user_public_key_id}", "${var.temp_public_key_id}"]

  # Specify the ssh connection
  connection {
    user        = "${var.ssh_user}"
    private_key = "${var.temp_private_key}"
    host        = "${self.ipv4_address}"
    timeout     = "30m"
  }
  
  # Create the installation script
  provisioner "file" {
    source      = "${path.module}/${var.module_script}"
    destination = "install.sh"
  }

  # Execute the script remotely
  provisioner "remote-exec" {
    inline = [
      "chmod +x install.sh",
      "bash install.sh > /var/logs/mdm-install.log",
      "bash -c 'if [ \"${var.remove_temp_private_key}\" == \"true\" ] ; then KEY=$(echo \"${var.temp_public_key}\" | cut -c 9-); cd /root/.ssh; grep -v $KEY authorized_keys > authorized_keys.new; mv -f authorized_keys.new authorized_keys; chmod 600 authorized_keys; fi'",
      "${var.module_custom_commands}"
    ]
  }
}

output "public_ip" {
    value = "${ibmcloud_infra_virtual_guest.softlayer_virtual_guest.ipv4_address}"    
}