module "scripts" {
  source = "github.com/pk4media/terraform.scripts"
}

resource "aws_security_group" "server" {
  name = "${var.name}-server"
  description = "Consul server permissions."

  vpc_id = "${var.vpc_id}"

  tags {
    Name = "${var.name}-server"
    Environment = "${var.environment}"
    Service = "consul"
  }

  ingress {
    from_port = 8300
    to_port = 8300
    protocol = "tcp"
    security_groups = ["${aws_security_group.agent.id}"]
  }

  ingress {
    from_port = 8302
    to_port = 8302
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = 8302
    to_port = 8302
    protocol = "udp"
    self = true
  }

  // Outbound internet access
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "agent" {
  name = "${var.name}-agent"
  description = "Consul agent permissions."

  vpc_id = "${var.vpc_id}"

  tags {
    Name = "${var.name}-agent"
    Environment = "${var.environment}"
    Service = "consul"
  }

  ingress {
    from_port = 8301
    to_port = 8301
    protocol = "tcp"
    self = true
  }

  ingress {
    from_port = 8301
    to_port = 8301
    protocol = "udp"
    self = true
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
    bootstrap_expect        = "${length(split(",", var.private_subnets))}"
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
  count         = "${length(split(",", var.private_subnets))}"

  # Dynamically get the appropriate Consul AMI
  ami           = "${element(split(",", atlas_artifact.consul.metadata_full.ami_id), index(split(",", atlas_artifact.consul.metadata_full.region), var.region))}"
  instance_type = "${var.instance_type}"
  key_name      = "${var.ec2_key_name}"
  subnet_id     = "${element(split(",", var.subnet_ids), count.index)}"

  instance_type = "${var.instance_type}"

  vpc_security_group_ids = [
  "${var.bastion_security_group_id}",
  "${aws_security_group.server.id}",
  "${aws_security_group.agent.id}"
  ]

  tags {
    Name = "${var.name}"
    Environment = "${var.environment}"
    Service = "consul"
  }

  connection {
    user = "ubuntu"
    host = "${self.private_ip}"
    private_key = "${var.private_key}"
    bastion_host = "${var.bastion_host}"
    bastion_user = "${var.bastion_user}"
    bastion_private_key = "${var.bastion_private_key}"
  }

  # Copy Consul certificates
  provisioner "remote-exec" {
    inline = [
    "${template_file.consul_tls.rendered}"
    ]
  }

  # Provision the Consul server
  provisioner "remote-exec" {
    inline = [
    "${template_file.consul.rendered}"
    ]
  }

  provisioner "remote-exec" {
    script = "${path.module}/wait_join.sh"
  }

  lifecycle {
    create_before_destroy = true
  }
}
