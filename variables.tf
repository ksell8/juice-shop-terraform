variable "aws_region" {
  description = "AWS region to deploy into"
  type        = string
}

variable "students" {
  description = "List of student names, one Juice Shop instance per student. Names are used as the resource keys (so adding/removing a student only touches that student's instance) and become the DNS subdomain, e.g. \"alice\" -> juiceshop-alice.example.com. Use lowercase, DNS-safe names (letters, numbers, hyphens)."
  type        = list(string)

  validation {
    condition     = length(var.students) == length(toset(var.students))
    error_message = "Student names must be unique."
  }

  validation {
    condition     = alltrue([for s in var.students : can(regex("^[a-z0-9-]+$", s))])
    error_message = "Student names must be lowercase letters, numbers, and hyphens only (they're used in DNS names)."
  }
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_id" {
  description = "AMI ID with Docker + Docker Compose plugin baked in (and /opt/juiceshop/docker-compose.yml already present)"
  type        = string
}

variable "root_volume_size" {
  description = "Size (GiB) of the root EBS volume. Juice Shop image + node_modules + docker overlay + logs/db comfortably fit under 20GB; bumped up for headroom."
  type        = number
  default     = 20
}

variable "root_volume_type" {
  description = "EBS volume type for the root volume"
  type        = string
  default     = "gp3"
}

variable "allowed_http_cidr" {
  description = "CIDR allowed to reach Juice Shop on port 3000"
  type        = string
  default     = "0.0.0.0/0"
}

variable "name_prefix" {
  description = "Prefix used for naming resources"
  type        = string
  default     = "juiceshop"
}

variable "route53_zone_name" {
  description = "Name of the existing Route 53 hosted zone (e.g. example.com), including trailing dot or not - both work"
  type        = string
}

variable "subdomain" {
  description = "Subdomain prefix to create under the zone. Each student gets subdomain-<student>.zone, e.g. 'juiceshop' + 'alice' -> juiceshop-alice.example.com."
  type        = string
  default     = "juiceshop"
}

variable "dns_ttl" {
  description = "TTL (seconds) for the Route 53 A records"
  type        = number
  default     = 300
}
