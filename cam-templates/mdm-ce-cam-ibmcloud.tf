{
  "provider": {
    "ibmcloud": {
    }
  },
  
  "variable": {
    "customer": {
      "description": "Name of the customer (Single word, all letters in small)"
    },
		"datacenter": {
      "description": "Softlayer datacenter where infrastructure resources will be deployed",
			"default": "dal09"
    },
    "public_ssh_key": {
      "description": "Public SSH key used to connect to the virtual guest"
    }
  },
  
  "resource": {
    "tls_private_key": {
      "ssh": {
        "algorithm": "RSA"
      }
    },
    "ibmcloud_infra_ssh_key": {
      "cam_public_key": {
        "label": "CAM Public Key",
        "public_key": "${var.public_ssh_key}"
      },
      "temp_public_key": {
        "label": "Temp Public Key",
        "public_key": "${tls_private_key.ssh.public_key_openssh}"
      }
    }
  },
  
	"module": {
    "install_mdm_ibmcloud": {
      "source": "git::https://github.com/santoshjpawar/mdm-deploy.git?ref=master//ibmcloud/virtual_guest/small",
      "hostname": "mdm-node-${var.customer}",
      "datacenter": "${var.datacenter}",
      "user_public_key_id": "${ibmcloud_infra_ssh_key.cam_public_key.id}",
      "temp_public_key_id": "${ibmcloud_infra_ssh_key.temp_public_key.id}",
      "temp_public_key": "${tls_private_key.ssh.public_key_openssh}",  
      "temp_private_key": "${tls_private_key.ssh.private_key_pem}",
      "module_script": "../files/install.sh",
      "os_reference_code": "CENTOS_7_64",
      "domain": "cam.ibm.com"
    }
  },
	"output": {
    "You can access the MDMCE application using the following url": {
      "value": "http://${module.install_mdm_ibmcloud.public_ip}:7507/utils/enterLogin.jsp"
    }
  }
}