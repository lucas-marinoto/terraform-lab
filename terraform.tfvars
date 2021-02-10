
region = "us-east-1"

# subnet_prefix = ["10.0.1.0/24","10.0.2.0/24"]
subnet_prefix = [
    { cidr_block = "10.0.1.0/24", name = "Tutorial Private Subnet 1", availability_zone = "us-east-1a" }, 
    { cidr_block = "10.0.2.0/24", name = "Tutorial Private Subnet 2", availability_zone = "us-east-1b" }
    ]

# Database Variables
rds_instance_identifier = "tutorial-db-instance"
database_name = "sample"
database_user = "tutorial_user"
instance_class = "db.t2.micro"

# EC2 Variables
ami_id = "ami-047a51fa27710816e"
instance_type = "t2.micro"

