module "scripts" {
  source = "github.com/pk4media/terraform.scripts"
}

resource "template_file" "install_ca" {
  template = "${file(module.scripts.ubuntu_install_ca)}"

  vars {
    name = "custom"
    ca   = "${var.ca}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "template_file" "consul_tls" {
  template = "${file(module.scripts.ubuntu_consul_tls_setup)}"

  vars {
    ca   = "${var.ca}"
    cert = "${var.tls_cert}"
    key  = "${var.tls_key}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "template_file" "consul" {
  template = "${file(module.scripts.ubuntu_consul_setup)}"

  vars {
    datacenter              = "${var.region}"
    atlas_token             = "${var.atlas_token}"
    atlas_username          = "${var.atlas_username}"
    atlas_environment       = "${var.atlas_environment}"
    bootstrap_expect        = "${var.nodes}"
    encryption              = "${var.encryption}"
    acl_datacenter          = "${var.acl_datacenter}"
    acl_master_token        = "${var.acl_master_token}"
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "atlas_artifact" "consul" {
  name = "${var.atlas_username}/consul"
  type = "amazon.ami"
  version = "${var.ami_artifact_version}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_instance" "consul" {
  count         = "${var.nodes}"

  # Dynamically get the appropriate Consul AMI
  ami           = "${element(split(",", atlas_artifact.consul.metadata_full.ami_id), index(split(",", atlas_artifact.consul.metadata_full.region), var.region))}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.ec2_key_name}"

  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"
  private_ip    = "${element(split(",", var.private_ips), count.index)}"

  vpc_security_group_ids = [
  "${var.bastion_security_group_id}",
  "${var.server_security_group_id}",
  "${var.agent_security_group_id}"
  ]

  tags {
    Name = "${var.name}"
    Environment = "${var.environment}"
    Service = "consul"
  }

  connection {
    user = "${var.user}"
    host = "${self.private_ip}"
    private_key = "${var.private_key}"
    bastion_host = "${var.bastion_host}"
    bastion_user = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  provisioner "remote-exec" {
    inline = [
    "${template_file.install_ca.rendered}"
    ]
  }

  provisioner "remote-exec" {
    inline = [
    "${template_file.consul_tls.rendered}",
    "${template_file.consul.rendered}"
    ]
  }

  provisioner "remote-exec" {
    script = "${path.module}/wait_join.sh"
  }

  lifecycle {
    create_before_destroy = true
    prevent_destroy       = true
  }
}
