provider "aws" {
access_key = "${var.access_key}"
secret_key = "${var.secret_key}"
region = "${var.aws_region}"
}

###########
# Network #
###########

resource "aws_vpc" "CodeSampleVpc" {
    cidr_block = "10.0.0.0/16"
    enable_dns_support = true
    enable_dns_hostnames = true
    tags {
      Name = "My code sample vpc"
    }
}

###################
# External Access #
###################

resource "aws_internet_gateway" "CodeSamplegw" {
   vpc_id = "${aws_vpc.CodeSampleVpc.id}"
    tags {
        Name = "internet gw"
    }
}


resource "aws_route_table" "public" {
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"
  tags {
      Name = "Public"
  }
  route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.CodeSamplegw.id}"
    }
}

##################
# Public subnets #
##################

resource "aws_subnet" "CodeSamplePublicSubnet-0" {
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"
  cidr_block = "10.0.0.0/24"
  tags {
        Name = "CodeSamplePublicSubnet-0"
  }
  availability_zone = "${var.zones[0]}"
}
resource "aws_route_table_association" "PublicCodeSample-2" {
    subnet_id = "${aws_subnet.CodeSamplePublicSubnet-0.id}"
    route_table_id = "${aws_route_table.public.id}"
}

resource "aws_subnet" "CodeSamplePublicSubnet-1" {
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"
  cidr_block = "10.0.1.0/24"
  tags {
        Name = "CodeSamplePublicSubnet-1"
  }
  availability_zone = "${var.zones[1]}"
}
resource "aws_route_table_association" "PublicCodeSample-1" {
    subnet_id = "${aws_subnet.CodeSamplePublicSubnet-1.id}"
    route_table_id = "${aws_route_table.public.id}"
}

###################
# Private subnets #
###################

resource "aws_subnet" "CodeSamplePrivateSubnet-0" {
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"
  cidr_block = "10.0.2.0/24"
  tags {
        Name = "CodeSamplePrivateSubnet-0"
  }
  availability_zone = "${var.zones[0]}"
}
resource "aws_subnet" "CodeSamplePrivateSubnet-1" {
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"
  cidr_block = "10.0.3.0/24"
  tags {
        Name = "CodeSamplePrivateSubnet-1"
  }
  availability_zone = "${var.zones[1]}"
}

###########################################
# Security group for django ec2 instances #
###########################################

resource "aws_security_group" "CodeSamplewebsg" {
  name = "CodeSamplewebsg"
  tags {
        Name = "CodeSamplewebsg"
  }
  description = "allow connection 8000 for django, http and ssh"
  vpc_id = "${aws_vpc.CodeSampleVpc.id}"

  ingress {
        from_port = 80
        to_port = 80
        protocol = "TCP"
        cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = "8000"
    to_port = "8000"
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

###########################
# Security group for alb  #
###########################

resource "aws_security_group" "alb" {
  name        = "alb"
  tags {
        Name = "alb_sg"
  }
  description = "allow connection 8000 for django"
  vpc_id      = "${aws_vpc.CodeSampleVpc.id}"

  # HTTP access from anywhere
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


#################
# Web instance 1#
#################

resource "aws_instance" "codesample_web0" {
  ami = "${var.ami}"
  instance_type =  "${var.instance_type}"
  availability_zone = "${var.zones[0]}"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.CodeSamplePublicSubnet-0.id}"
  vpc_security_group_ids = ["${aws_security_group.CodeSamplewebsg.id}"]
  key_name = "mycodesampleKey"
  tags {
    Name = "django_web_0"
  }
  provisioner "local-exec" {
    command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key=./mycodesampleKey.pem -i '${self.public_ip},' django.yml"
  }
}

################
# Web instance2 #
################

resource "aws_instance" "codesample_web1" {
  ami = "${var.ami}"
  instance_type =  "${var.instance_type}"
  availability_zone = "${var.zones[1]}"
  associate_public_ip_address = true
  subnet_id = "${aws_subnet.CodeSamplePublicSubnet-1.id}"
  vpc_security_group_ids = ["${aws_security_group.CodeSamplewebsg.id}"]
  key_name = "mycodesampleKey"
  tags {
    Name = "django_web_1"
  }
  provisioner "local-exec" {
    command = "sleep 120; ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook -u ubuntu --private-key=./mycodesampleKey.pem -i '${self.public_ip},' django.yml"
  }
}


############
# Alb      #
############

resource "aws_alb" "web-frontend" {
  name            = "web-frontend"
  internal        = false
  security_groups = ["${aws_security_group.alb.id}"]
  subnets         = ["${aws_subnet.CodeSamplePublicSubnet-0.id}", "${aws_subnet.CodeSamplePublicSubnet-1.id}"]
tags {
    Environment = "test"
  }  
}
resource "aws_alb_target_group" "web-frontend" {
  name      = "web-frontend-gp"
  port      = 8000
  protocol  = "HTTP"
  vpc_id    = "${aws_vpc.CodeSampleVpc.id}"
}
resource "aws_alb_target_group_attachment" "django_web0" {
  target_group_arn = "${aws_alb_target_group.web-frontend.arn}"
  target_id        = "${aws_instance.codesample_web0.id}"
  port             = 8000
}
resource "aws_alb_target_group_attachment" "django_web1" {
  target_group_arn = "${aws_alb_target_group.web-frontend.arn}"
  target_id        = "${aws_instance.codesample_web1.id}"
  port             = 8000
}
resource "aws_alb_listener" "front_end" {
  load_balancer_arn = "${aws_alb.web-frontend.arn}"
  port              = "8000"
  protocol          = "HTTP"
  default_action {
    target_group_arn = "${aws_alb_target_group.web-frontend.arn}"
    type             = "forward"
  }
}
