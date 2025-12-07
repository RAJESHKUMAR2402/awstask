data "aws_ami" "amazon_linux_task2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "rajesh-kumar-ec2-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "ec2_s3_read" {
  name = "rajesh-kumar-ec2-s3-read"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::rajesh-kumar-resume/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "rajesh-kumar-ec2-profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_security_group" "public_web_sg" {
  name   = "rajesh-kumar-public-web-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rajesh_kumar_public_web_sg" }
}

resource "aws_instance" "public_web" {
  ami                         = data.aws_ami.amazon_linux_task2.id
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_1.id
  vpc_security_group_ids      = [aws_security_group.public_web_sg.id]
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.ec2_profile.name

  user_data = <<EOF
#!/bin/bash
yum update -y
yum install -y awscli
amazon-linux-extras install -y nginx1
systemctl enable nginx
systemctl start nginx
aws s3 cp s3://rajesh-kumar-resume/index.html /usr/share/nginx/html/index.html
EOF

  tags = { Name = "rajesh_kumar_public_ec2" }
}
