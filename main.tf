terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# 1. Create vpc
resource "aws_vpc" "my_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.name}-vpc"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "${var.name}-igw"
  }
}

# 3. Create Custom Route Table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "${var.name}-route-table"
  }
}

# 4. Create Subnets
# RDS requires 2 subnets in different availability zones
resource "aws_subnet" "my_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.0.0/20"
  availability_zone = var.availability_zone_1

  tags = {
    Name = "${var.name}-subnet-1"
  }
}

resource "aws_subnet" "my_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  cidr_block        = "10.0.16.0/20"
  availability_zone = var.availability_zone_2

  tags = {
    Name = "${var.name}-subnet-2"
  }
}

# 5. Associate subnet with Route Table
resource "aws_route_table_association" "my_subnet_association_us_east_1a" {
  subnet_id      = aws_subnet.my_subnet_1.id
  route_table_id = aws_route_table.my_route_table.id
}

resource "aws_route_table_association" "my_subnet_association_us_east_1b" {
  subnet_id      = aws_subnet.my_subnet_2.id
  route_table_id = aws_route_table.my_route_table.id
}

# 6. Create Security Group to allow ports
resource "aws_security_group" "my_security_group" {
  name        = "allow_web_traffic"
  description = "Allow necessary web traffic"
  vpc_id      = aws_vpc.my_vpc.id

  # Inbound rules
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Elastic Beanstalk default port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound rules
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create Elastic Beanstalk Application
resource "aws_elastic_beanstalk_application" "my_application" {
  name        = "${var.name}-app"
  description = "Application for ${var.name}"
}

# 8. Create Elastic Beanstalk Environment
resource "aws_elastic_beanstalk_environment" "my_environment" {
  name                   = "${var.name}-env"
  application            = aws_elastic_beanstalk_application.my_application.name
  solution_stack_name    = var.solution_stack_name
  tier                   = "WebServer"
  wait_for_ready_timeout = "20m"

  # Database settings
  setting {
    name      = "DBEngine"
    namespace = "aws:rds:dbinstance"
    value     = "mysql"
  }

  setting {
    name      = "DBEngineVersion"
    namespace = "aws:rds:dbinstance"
    value     = "8.0.35"
  }

  setting {
    name      = "DBUser"
    namespace = "aws:rds:dbinstance"
    value     = var.database_username
  }

  setting {
    name      = "DBPassword"
    namespace = "aws:rds:dbinstance"
    value     = var.database_password
  }

  setting {
    name      = "DBInstanceClass"
    namespace = "aws:rds:dbinstance"
    value     = "db.t2.micro"
  }

  setting {
    name      = "DBSubnets"
    namespace = "aws:ec2:vpc"
    value     = "${aws_subnet.my_subnet_1.id},${aws_subnet.my_subnet_2.id}"
  }

  # EC2 settings
  setting {
    name      = "EC2KeyName"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = var.ec2_key_name
  }

  setting {
    name      = "SecurityGroups"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = aws_security_group.my_security_group.id
  }

  setting {
    name      = "AssociatePublicIpAddress"
    namespace = "aws:ec2:vpc"
    value     = "true"
  }

  setting {
    name      = "VPCId"
    namespace = "aws:ec2:vpc"
    value     = aws_vpc.my_vpc.id
  }

  setting {
    name      = "Subnets"
    namespace = "aws:ec2:vpc"
    value     = "${aws_subnet.my_subnet_1.id},${aws_subnet.my_subnet_2.id}"
  }

  setting {
    name      = "InstanceTypes"
    namespace = "aws:ec2:instances"
    value     = "t3.micro, t3.small"
  }

  setting {
    name      = "SupportedArchitectures"
    namespace = "aws:ec2:instances"
    value     = "x86_64"
  }

  # Elastic Load Balancing
  setting {
    name      = "ELBScheme"
    namespace = "aws:ec2:vpc"
    value     = "public"
  }

  setting {
    name      = "ELBSubnets"
    namespace = "aws:ec2:vpc"
    value     = "${aws_subnet.my_subnet_1.id},${aws_subnet.my_subnet_2.id}"
  }

  # Default sample app
  # setting {
  #   name      = "AppSource"
  #   namespace = "aws:cloudformation:template:parameter"
  #   value     = "https://elasticbeanstalk-platform-assets-us-east-1.s3.amazonaws.com/stalks/eb_go1_amazon_linux_2023_1.0.259.0_20240123011154/sampleapp/EBSampleApp-Go.zip"
  # }

  # The rest of the settings are imported from an environment I created manually
  # For many of them, they are default settings and I am not exactly sure what they do lol
  setting {
    name      = "Automatically Terminate Unhealthy Instances"
    namespace = "aws:elasticbeanstalk:monitoring"
    value     = "true"
  }

  setting {
    name      = "Availability Zones"
    namespace = "aws:autoscaling:asg"
    value     = "Any"
  }

  setting {
    name      = "BatchSize"
    namespace = "aws:elasticbeanstalk:command"
    value     = "100"
  }

  setting {
    name      = "BatchSizeType"
    namespace = "aws:elasticbeanstalk:command"
    value     = "Percentage"
  }

  setting {
    name      = "ConfigDocument"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value     = "{\"Version\":1,\"CloudWatchMetrics\":{\"Instance\":{},\"Environment\":{}},\"Rules\":{\"Environment\":{\"ELB\":{\"ELBRequests4xx\":{\"Enabled\":true}},\"Application\":{\"ApplicationRequests4xx\":{\"Enabled\":true}}}}}"
  }

  setting {
    name      = "Cooldown"
    namespace = "aws:autoscaling:asg"
    value     = "360"
  }

  setting {
    name      = "DBAllocatedStorage"
    namespace = "aws:rds:dbinstance"
    value     = "5"
  }

  setting {
    name      = "DBDeletionPolicy"
    namespace = "aws:rds:dbinstance"
    value     = "Delete"
  }

  setting {
    name      = "DefaultSSHPort"
    namespace = "aws:elasticbeanstalk:control"
    value     = "22"
  }

  setting {
    name      = "DeleteOnTerminate"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    value     = "false"
  }

  setting {
    name      = "DeleteOnTerminate"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    value     = "false"
  }

  setting {
    name      = "DeploymentPolicy"
    namespace = "aws:elasticbeanstalk:command"
    value     = "AllAtOnce"
  }

  setting {
    name      = "DisableIMDSv1"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "true"
  }

  setting {
    name      = "EnableCapacityRebalancing"
    namespace = "aws:autoscaling:asg"
    value     = "false"
  }

  setting {
    name      = "EnableSpot"
    namespace = "aws:ec2:instances"
    value     = "false"
  }

  setting {
    name      = "EnhancedHealthAuthEnabled"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value     = "false"
  }

  setting {
    name      = "EnvironmentType"
    namespace = "aws:elasticbeanstalk:environment"
    value     = "SingleInstance"
  }

  setting {
    name      = "HasCoupledDatabase"
    namespace = "aws:rds:dbinstance"
    value     = "true"
  }

  setting {
    name      = "HealthCheckSuccessThreshold"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value     = "Ok"
  }

  setting {
    name      = "HealthStreamingEnabled"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    value     = "false"
  }

  setting {
    name      = "HooksPkgUrl"
    namespace = "aws:cloudformation:template:parameter"
    value     = "https://elasticbeanstalk-platform-assets-us-east-1.s3.amazonaws.com/stalks/eb_go1_amazon_linux_2023_1.0.259.0_20240123011154/lib/hooks.tar.gz"
  }

  setting {
    name      = "IamInstanceProfile"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "aws-elasticbeanstalk-ec2-role"
  }

  setting {
    name      = "IgnoreHealthCheck"
    namespace = "aws:elasticbeanstalk:command"
    value     = "false"
  }

  setting {
    name      = "ImageId"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "ami-0cd93a4828bfbbaad"
  }

  setting {
    name      = "InstancePort"
    namespace = "aws:cloudformation:template:parameter"
    value     = "80"
  }

  setting {
    name      = "InstanceRefreshEnabled"
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    value     = "false"
  }

  setting {
    name      = "InstanceType"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "t3.micro"
  }

  setting {
    name      = "InstanceTypeFamily"
    namespace = "aws:cloudformation:template:parameter"
    value     = "t3"
  }

  setting {
    name      = "LaunchTimeout"
    namespace = "aws:elasticbeanstalk:control"
    value     = "0"
  }

  setting {
    name      = "LaunchType"
    namespace = "aws:elasticbeanstalk:control"
    value     = "Migration"
  }

  setting {
    name      = "LogPublicationControl"
    namespace = "aws:elasticbeanstalk:hostmanager"
    value     = "false"
  }

  setting {
    name      = "ManagedActionsEnabled"
    namespace = "aws:elasticbeanstalk:managedactions"
    value     = "false"
  }

  setting {
    name      = "MaxSize"
    namespace = "aws:autoscaling:asg"
    value     = "1"
  }

  setting {
    name      = "MinSize"
    namespace = "aws:autoscaling:asg"
    value     = "1"
  }

  setting {
    name      = "MonitoringInterval"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "5 minute"
  }

  setting {
    name      = "MultiAZDatabase"
    namespace = "aws:rds:dbinstance"
    value     = "false"
  }

  setting {
    name      = "Notification Protocol"
    namespace = "aws:elasticbeanstalk:sns:topics"
    value     = "email"
  }

  setting {
    name      = "PreferredStartTime"
    namespace = "aws:elasticbeanstalk:managedactions"
    value     = "MON:00:21"
  }

  setting {
    name      = "RetentionInDays"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    value     = "7"
  }

  setting {
    name      = "RetentionInDays"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs:health"
    value     = "7"
  }

  setting {
    name      = "RollbackLaunchOnFailure"
    namespace = "aws:elasticbeanstalk:control"
    value     = "false"
  }

  setting {
    name      = "RollingUpdateEnabled"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    value     = "false"
  }

  setting {
    name      = "RollingUpdateType"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    value     = "Time"
  }

  setting {
    name      = "SSHSourceRestriction"
    namespace = "aws:autoscaling:launchconfiguration"
    value     = "tcp,22,22,0.0.0.0/0"
  }

  setting {
    name      = "ServiceRole"
    namespace = "aws:elasticbeanstalk:environment"
    value     = "arn:aws:iam::063321195667:role/aws-elasticbeanstalk-service-role"
  }

  setting {
    name      = "ServiceRoleForManagedUpdates"
    namespace = "aws:elasticbeanstalk:managedactions"
    value     = "arn:aws:iam::063321195667:role/aws-elasticbeanstalk-service-role"
  }

  setting {
    name      = "SpotFleetOnDemandAboveBasePercentage"
    namespace = "aws:ec2:instances"
    value     = "0"
  }

  setting {
    name      = "SpotFleetOnDemandBase"
    namespace = "aws:ec2:instances"
    value     = "0"
  }

  setting {
    name      = "StreamLogs"
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    value     = "false"
  }

  setting {
    name      = "SystemType"
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    value     = "basic"
  }

  setting {
    name      = "Timeout"
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    value     = "PT30M"
  }

  setting {
    name      = "Timeout"
    namespace = "aws:elasticbeanstalk:command"
    value     = "600"
  }

  setting {
    name      = "UpdateLevel"
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    value     = "minor"
  }

  setting {
    name      = "XRayEnabled"
    namespace = "aws:elasticbeanstalk:xray"
    value     = "false"
  }
}
