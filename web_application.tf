

resource "tls_private_key" "example" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ssh_deployer" {
  key_name   = "${var.key_name}"
  public_key = "${tls_private_key.example.public_key_openssh}"
}

resource "aws_instance" "webserver" {
  ami           = var.ami_id
  instance_type = var.instance_type
  key_name      = aws_key_pair.ssh_deployer.key_name
  # key_name      = "keyparViginia"
  subnet_id     = aws_subnet.tutorial_public_subnet.id
  security_groups             = [aws_security_group.tutorial_securitygroup.id]
  associate_public_ip_address = true
  iam_instance_profile = "EC2-S3-ReadOnly-All"
  tags = {
    Name = "tutorial-web-server"
  }
  user_data = templatefile("${path.module}/provision.sh", { rds_endpoint = "${aws_db_instance.mysql_database.endpoint}",
        rds_username = "${var.database_user}",
        rds_password = "${var.database_password}",
        rds_database_name = "${var.database_name}"
    })
}


output "URL_Instance" {

  value = "http://${aws_instance.webserver.public_ip}/SamplePage.php"
  
}