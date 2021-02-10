
# # Create Security Group for DB and EC2
resource "aws_security_group" "rds_sg" {
  name        = "tutorial-db-securitygroup"
  description = "RDS MySQL server"
  vpc_id      =  aws_vpc.tutorial_vpc.id
  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.tutorial_securitygroup.id]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "tutorial-db-securitygroup"
  }
}


# # Create a DB subnet Group
resource "aws_db_subnet_group" "subnet_DB_group" {
  name        = "tutorial-db-subnet-group"
  description = "tutorial-db-subnet-group"
  # subnet_ids  = [aws_subnet.tutorial_private_subnet.*.id]
  subnet_ids  = concat(aws_subnet.tutorial_private_subnet.*.id,aws_subnet.tutorial_public_subnet.*.id)
  tags = {
    "name" = "tutorial-db-subnet-group"
  }
}


# Create a RDS MySQL database
resource "aws_db_instance" "mysql_database" {
  identifier                = var.rds_instance_identifier
  allocated_storage         = 20
  engine                    = "mysql"
  engine_version            = "5.6.35"
  instance_class            = var.instance_class
  name                      = var.database_name
  username                  = var.database_user
  password                  = var.database_password
  db_subnet_group_name      = aws_db_subnet_group.subnet_DB_group.id
  vpc_security_group_ids    = [aws_security_group.rds_sg.id]
  skip_final_snapshot       = true
  final_snapshot_identifier = "Ignore"
}

output "enpoint_database" {
  value = aws_db_instance.mysql_database.endpoint
}