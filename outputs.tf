output "user" {
  value = "${var.user}"
}
output "instance_ids" {
  value = "${join(",", aws_instance.consul.*.id)}"
}
output "private_ips" {
  value = "${join(",", aws_instance.consul.*.private_ip)}"
}

output "agent_security_group_id" {
  value = "${aws_security_group.agent.id}"
}

output "datacenter" {
  value = "${var.region}"
}
