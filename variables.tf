variable "name" {
  type        = string
  description = "Name of the project"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "access_key" {
  type        = string
  description = "AWS access key"
}

variable "secret_key" {
  type        = string
  description = "AWS secret key"
}

variable "availability_zone_1" {
  type        = string
  description = "The first AWS availability zone"
}

variable "availability_zone_2" {
  type        = string
  description = "The second AWS availability zone"
}

variable "solution_stack_name" {
  type        = string
  description = "The name of the Elastic Beanstalk solution stack"
}

variable "database_username" {
  type        = string
  description = "The username for the database"
}

variable "database_password" {
  type        = string
  description = "The password for the database"
}

variable "ec2_key_name" {
  type        = string
  description = "The name of the EC2 key pair"

}
