data "aws_ami" "amazon_linux_task3" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_iam_role" "asg_role" {
  name = "rajesh-kumar-asg-role"

  assume_role_policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "asg_s3_read" {
  name = "rajesh-kumar-asg-s3-read"
  role = aws_iam_role.asg_role.id

  policy = jsonencode({
    Version   = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = ["arn:aws:s3:::rajesh-kumar-resume/*"]
    }]
  })
}

resource "aws_iam_instance_profile" "asg_profile" {
  name = "rajesh-kumar-asg-profile"
  role = aws_iam_role.asg_role.name
}

resource "aws_security_group" "alb_sg" {
  name   = "rajesh-kumar-alb-sg"
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

  tags = { Name = "rajesh_kumar_alb_sg" }
}

resource "aws_security_group" "private_web_sg" {
  name   = "rajesh-kumar-private-web-sg"
  vpc_id = aws_vpc.main_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "rajesh_kumar_private_web_sg" }
}

resource "aws_lb" "alb" {
  name               = "rajesh-kumar-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  tags               = { Name = "rajesh_kumar_alb" }
}

resource "aws_lb_target_group" "tg" {
  name     = "rajesh-kumar-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id
  tags     = { Name = "rajesh_kumar_target_group" }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

resource "aws_launch_template" "web_lt" {
  name_prefix   = "rajesh-kumar-web-lt-"
  image_id      = data.aws_ami.amazon_linux_task3.id
  instance_type = "t2.micro"

  vpc_security_group_ids = [aws_security_group.private_web_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.asg_profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash
yum update -y
yum install -y awscli
amazon-linux-extras install -y nginx1
systemctl enable nginx
systemctl start nginx
aws s3 cp s3://rajesh-kumar-resume/index.html /usr/share/nginx/html/index.html
EOF
  )
}

resource "aws_autoscaling_group" "web_asg" {
  name                = "rajesh-kumar-asg"
  min_size            = 2
  max_size            = 2
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  target_group_arns   = [aws_lb_target_group.tg.arn]

  launch_template {
    id      = aws_launch_template.web_lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "rajesh_kumar_private_ec2"
    propagate_at_launch = true
  }
}
