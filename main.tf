provider "aws" {
  region = "eu-central-1"
}

resource "aws_vpc" "webinar" {
  cidr_block = "10.10.0.0/16"
}

resource "aws_internet_gateway" "webinar" {
  vpc_id = "${aws_vpc.webinar.id}"
}

resource "aws_route" "internet_access" {
  route_table_id         = "${aws_vpc.webinar.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.webinar.id}"
}


resource "aws_subnet" "webinar1" {
  vpc_id                  = "${aws_vpc.webinar.id}"
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1a"
}

resource "aws_subnet" "webinar2" {
  vpc_id                  = "${aws_vpc.webinar.id}"
  cidr_block              = "10.10.2.0/24"
  map_public_ip_on_launch = true
  availability_zone = "eu-central-1b"
}

resource "aws_security_group" "elb" {
  name        = "Webinar_elb"
  description = "example pour le webinar"
  vpc_id      = "${aws_vpc.webinar.id}"

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
}


resource "aws_security_group" "webinar" {
  name        = "SG_instance"
  description = "regle de FW pour les instances"
  vpc_id      = "${aws_vpc.webinar.id}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.10.0.0/16"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_elb" "web" {
  name = "webinar-elb"

  subnets         = ["${aws_subnet.webinar1.id}","${aws_subnet.webinar2.id}"]
  security_groups = ["${aws_security_group.elb.id}"]
  instances       = ["${aws_instance.web1.id}","${aws_instance.web2.id}"]
 health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 5
  }

  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
 }

resource "aws_key_pair" "auth" {
  key_name   = "gael_aws"
  public_key = "${file(var.ssh_pub)}"
}

resource "aws_instance" "web1" {
          connection {
    user = "ec2-user"
    private_key = "${file(var.ssh_priv)}"

  }

  instance_type = "t2.micro"
  ami = "ami-ea26ce85"
  key_name = "gael_aws"
  vpc_security_group_ids = ["${aws_security_group.webinar.id}"]
  subnet_id = "${aws_subnet.webinar1.id}"
      tags {
        Name = "HTTP_WEB1"
    }
      provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nginx",
      "sudo /etc/init.d/nginx start",
      "sudo /usr/bin/curl -o /usr/share/nginx/html/index.html https://s3.eu-central-1.amazonaws.com/webinaras/index.html"
    ]
  }
}

resource "aws_instance" "web2" {
      connection {
    user = "ec2-user"
    private_key = "${file(var.ssh_priv)}"
  }

  instance_type = "t2.micro"
  ami = "ami-ea26ce85"
  key_name = "gael_aws"
  vpc_security_group_ids = ["${aws_security_group.webinar.id}"]
  subnet_id = "${aws_subnet.webinar2.id}"
      tags {
        Name = "HTTP_WEB2"
    }
      provisioner "remote-exec" {
    inline = [
      "sudo yum -y install nginx",
      "sudo /etc/init.d/nginx start",
      "sudo /usr/bin/curl -o /usr/share/nginx/html/index.html https://s3.eu-central-1.amazonaws.com/webinaras/index.html"
    ]
  }
}
