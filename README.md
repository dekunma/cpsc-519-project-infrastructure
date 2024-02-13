Terraform code to construct the infrastructure for the project.  
The code in this repository creates:
- 1 VPC with 2 public subnets
- 1 internet gateway
- 1 route table 
- 1 security group that allows necessary web traffic

And an Elastic Beanstalk environment with:
- 1 EC2 instance
- 1 MySQL database

The code in `settings` in `aws_elastic_beanstalk_environment` of `main.tf` was mainly created by importing from an environment I created manually.  
(Inspired by [This Aritical](https://medium.com/@anasanjaria/tip-for-creating-aws-elastic-beanstalk-environment-using-terraform-7c1acf6bb42d))  

## Usage
Install terraform on your machine.  

Rename `terraform.tfvars.example` to `terraform.tfvars` and fill in the necessary information.  

To plan the execution of the code, run:
```bash
terraform plan
```

To apply the code, run:
```bash
terraform apply
```

To destroy the infrastructure, run:
```bash
terraform destroy
```

## Notes
To make the RDS public accessible, please do so manually in the AWS console:  
https://stackoverflow.com/questions/22866490/how-do-i-change-the-publicly-accessible-option-for-amazon-rds