#!/bin/bash
# yum update -y
# yum install -y httpd.x86_64
# systemctl start httpd.service
# systemctl enable httpd.service
# echo “Hello World from $(hostname -f)” > /var/www/html/index.html


#!/bin/bash
sudo yum update -y
sudo amazon-linux-extras install -y lamp-mariadb10.2-php7.2 php7.2
sudo yum install -y httpd
sudo systemctl start httpd
sudo systemctl enable httpd
sudo groupadd www
sudo usermod -a -G www ec2-user
sudo chgrp -R www /var/www
sudo chmod 2775 /var/www
find /var/www -type d -exec sudo chmod 2775 {} +
find /var/www -type f -exec sudo chmod 0664 {} +
mkdir /var/www/inc
cd /var/www/inc
sudo echo "<?php
define('DB_SERVER', '${rds_endpoint}');
define('DB_USERNAME', '${rds_username}');
define('DB_PASSWORD', '${rds_password}');
define('DB_DATABASE', '${rds_database_name}');
?>" > dbinfo.inc
echo “O Servidor esta no Ar!! Hostmane: $(hostname -f)” > /var/www/html/index.html

# Copy S3 page to EC2
aws s3 cp s3://tutoriaawslmm/SamplePage.php /var/www/html/
