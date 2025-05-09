output "local_ip_cidr" {
  value = "${data.external.my_ip.result["ip"]}/32"
}

output "remote_server_public_ip" {
  value = aws_instance.temp_instance.public_ip
}


