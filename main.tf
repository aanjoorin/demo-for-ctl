provider "aws" {
  region  = "us-east-1"
}

data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
  owners = ["099720109477"]
}

data "template_file" "startup" {
  template = file("${path.module}/startup-install.sh")
  vars = {
    runner_set_namespace = var.runner_set_namespace
    controller_namespace = var.controller_namespace
    runner_image         = var.runner_image
    github_token         = var.github_token
    github_config_url    = var.github_config_url
  }
}

resource "aws_default_vpc" "default" {}

data "external" "myipaddr" {
  program = ["bash", "-c", "curl -s 'https://ipinfo.io/json'"]
}

resource "aws_security_group" "sg" {
  name        = "${var.name_prefix}-sg"
  description = "Allow SSH and HTTP/S traffic"
  vpc_id      = aws_default_vpc.default.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${data.external.myipaddr.result.ip}/32"]
  }

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

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "k8s" {
  count          = 3
  ami            = data.aws_ami.ubuntu.id
  instance_type  = var.instance_type
  key_name       = aws_key_pair.key_pair.key_name
  iam_instance_profile = aws_iam_instance_profile.profile.name
  vpc_security_group_ids = [aws_security_group.sg.id]
  user_data      = data.template_file.startup.rendered

  root_block_device {
    volume_size = var.root_volume_size
    volume_type = "gp3"
  }

  provisioner "file" {
    source      = "${path.module}/kind-config.yaml"
    destination = "/tmp/kind-config.yaml"

    connection {
      type        = "ssh"
      user        = "ubuntu"
      private_key = file("${path.module}/${aws_key_pair.key_pair.key_name}.pem")
      host        = self.public_dns
    }
  }

  tags = {
    Name = "${var.name_prefix}-k8s-instance-${count.index}"
  }
}

output "kind_cluster_nodes" {
  value = aws_instance.k8s[*].public_ip
}

