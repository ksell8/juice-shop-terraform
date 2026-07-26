data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "juiceshop" {
  name        = "${var.name_prefix}-sg"
  description = "Juice Shop access"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "Juice Shop web"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [var.allowed_http_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.name_prefix}-sg"
  }
}

# SSM Session Manager access in place of SSH: instances need no inbound port,
# just outbound internet (already allowed via egress above) to reach the
# SSM endpoints, plus this role/profile so the pre-installed SSM agent can
# register. Connect with: aws ssm start-session --target <instance-id>
resource "aws_iam_role" "ssm" {
  name = "${var.name_prefix}-ssm-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = {
    Name = "${var.name_prefix}-ssm-role"
  }
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ssm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ssm" {
  name = "${var.name_prefix}-ssm-profile"
  role = aws_iam_role.ssm.name
}

# Assumes the AMI already has docker + docker compose plugin installed,
# and /opt/juiceshop/docker-compose.yml baked in (see docker-compose.yml
# provided alongside this config). user_data just brings it up and makes
# sure it's rooted to persist across reboots.
locals {
  students = toset(var.students)
  # Deterministic subnet spread: index each student against the original
  # ordered list so instance placement doesn't shuffle when the set changes.
  student_idx = { for i, s in var.students : s => i }

  user_data = <<-EOF
    #!/bin/bash
    set -eux
    mkdir -p /opt/juiceshop/data /opt/juiceshop/logs
    # docker-compose.yml bind-mounts this file directly (not the data/ dir -
    # that dir also holds the image's seed assets under data/static/, which
    # startup needs on every boot). The file must exist before `compose up`
    # or Docker will create a directory at this path instead.
    touch /opt/juiceshop/data/juiceshop.sqlite
    chmod 666 /opt/juiceshop/data/juiceshop.sqlite
    # the container runs as a non-root user that doesn't own these host dirs
    chmod 777 /opt/juiceshop/logs
    cd /opt/juiceshop
    docker compose up -d
  EOF
}

resource "aws_instance" "juiceshop" {
  for_each                    = local.students
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = element(data.aws_subnets.default.ids, local.student_idx[each.key] % length(data.aws_subnets.default.ids))
  vpc_security_group_ids      = [aws_security_group.juiceshop.id]
  iam_instance_profile        = aws_iam_instance_profile.ssm.name
  associate_public_ip_address = true
  user_data                   = local.user_data

  root_block_device {
    volume_size           = var.root_volume_size
    volume_type           = var.root_volume_type
    delete_on_termination = true
    encrypted             = true
  }

  tags = {
    Name    = "${var.name_prefix}-${each.key}"
    Student = each.key
  }
}

# Static IP per instance so DNS doesn't break on stop/start or replacement
resource "aws_eip" "juiceshop" {
  for_each = local.students
  instance = aws_instance.juiceshop[each.key].id
  domain   = "vpc"

  tags = {
    Name    = "${var.name_prefix}-${each.key}"
    Student = each.key
  }
}

data "aws_route53_zone" "this" {
  name = var.route53_zone_name
}

# Each student gets their own subdomain: subdomain-<name>.zone
resource "aws_route53_record" "juiceshop" {
  for_each = local.students
  zone_id  = data.aws_route53_zone.this.zone_id
  name     = "${var.subdomain}-${each.key}"
  type     = "A"
  ttl      = var.dns_ttl
  records  = [aws_eip.juiceshop[each.key].public_ip]
}
