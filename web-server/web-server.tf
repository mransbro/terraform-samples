 locals {
   subnet_id     = "subnet-f0651234" # sit1-private-1a
   vpc_id        = "vpc-07fc1234"    #sit1
   instance_type = "t3.micro"
 }


 data "aws_ami" "amzn-linux-2023-ami" {
   most_recent = true
   owners      = ["amazon"]

   filter {
     name   = "name"
     values = ["al2023-ami-2023.*-x86_64"]
   }
 }

 data "aws_partition" "current" {}

 resource "aws_security_group" "sg" {
   name        = "web-server-test"
   description = "web-server-test"
   vpc_id      = local.vpc_id
   ingress {
     description = "HTTP-in"
     from_port   = 80
     to_port     = 80
     protocol    = "tcp"
     cidr_blocks = ["172.16.0.0/12", "192.168.0.0/16", "10.0.0.0/8"]
   }

   egress {
     from_port        = 0
     to_port          = 0
     protocol         = "-1"
     cidr_blocks      = ["0.0.0.0/0"]
     ipv6_cidr_blocks = ["::/0"]
   }

 }

 resource "aws_instance" "web" {
   ami             = data.aws_ami.amzn-linux-2023-ami.id
   instance_type   = local.instance_type
   subnet_id       = local.subnet_id
   security_groups = [aws_security_group.sg.id]
   iam_instance_profile = aws_iam_role.this.name

   user_data = <<-EOF
   #!/bin/bash
   # get admin privileges
   sudo su

   # install httpd (Linux 2 version)
   yum update -y
   yum install -y httpd.x86_64
   systemctl start httpd.service
   systemctl enable httpd.service
   echo "Hello World from $(hostname -f)" > /var/www/html/index.html
   EOF

   tags = {
     Name = "web-server-test"
   }

   volume_tags = {
     Name = "web-server-test"
   }
 }

 # Create IAM Role
 resource "aws_iam_role" "this" {
   name               = "web-server-test"
   assume_role_policy = <<EOF
 {
   "Version": "2012-10-17",
   "Statement": {
     "Effect": "Allow",
     "Principal": {"Service": "ec2.amazonaws.com"},
     "Action": "sts:AssumeRole"
   }
 }
 EOF
 }

 # Create IAM Instance Profile
 resource "aws_iam_instance_profile" "this" {
   name = "web-server-test"
   role = aws_iam_role.this.name
 }

 # Create IAM Role Policy Attachment
 resource "aws_iam_role_policy_attachment" "this" {
   role       = aws_iam_role.this.name
   policy_arn = "arn:${data.aws_partition.current.partition}:iam::aws:policy/AmazonSSMManagedInstanceCore"
 }
