
provider "aws" {
  region = "us-east-1" 
}

# VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
}

#  public subnet
resource "aws_subnet" "public_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Public Subnet"
  }
}

# private subnet
resource "aws_subnet" "private_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"  

  tags = {
    Name = "Private Subnet"
  }
}

# SG for EC2
resource "aws_security_group" "apache_server_sg" {
  vpc_id = aws_vpc.my_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Ingress for HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Apache Server SG"
  }
}

# EC2  in the public subnet
resource "aws_instance" "apache_server" {
  ami           = "ami-03cc8375791cb8bcf"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id

 
  security_groups = [aws_security_group.apache_server_sg.id]

 user_data = file("${path.module}/scripts/apache-cloudwatch_agent.sh")

  tags = {
    Name = "Apache Server"
    OS = "Ubuntu"
  }
}
# SNS Topic for notifications
resource "aws_sns_topic" "cpu_alert_topic" {
  name = "cpu_alerts"
}

# SNS subscription to send an email when the alarm is triggered
resource "aws_sns_topic_subscription" "email_alert" {
  topic_arn = aws_sns_topic.cpu_alert_topic.arn
  protocol  = "email"
  endpoint  = "chandramishra993@gmail.com"
}

# CloudWatch Alarm for CPU usage
resource "aws_cloudwatch_metric_alarm" "cpu_alarm" {
  alarm_name          = "High-CPU-Usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This alarm triggers when CPU usage exceeds 80%."
  actions_enabled     = true
  alarm_actions       = [aws_sns_topic.cpu_alert_topic.arn]
  ok_actions          = [aws_sns_topic.cpu_alert_topic.arn]
  insufficient_data_actions = []

  dimensions = {
    InstanceId = aws_instance.apache_server.id
  }
}
