# Terraform Lab


# IAM Role EC2 - S3

Is necessary create a Role to communicate between S3 and EC2 with name EC2-S3-ReadOnly-All

# Bucket S3

Create a new bucket to store the php page with name tutoriaawslmm and upload the page SamplePage.php

Is possible modify the name of bucket in provision.sh

```bash
aws s3 cp s3://tutoriaawslmm/SamplePage.php /var/www/html/
```

## Usage

To run this example you need to execute:

```bash
$ terraform init
$ terraform plan
$ $ terraform apply -var access_key={ACCESS_KEY_AWS} -var secret_key={SECRET_KEY_AWS} -var database_password={DATABASE_PASSWORD}
```
