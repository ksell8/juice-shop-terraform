# Juice Shop on EC2 (Terraform + Docker Compose)

This is a quick a dirty setup for OWASP Juice Shop.
- [What is OWASP Juice Shop?](https://owasp.org/www-project-juice-shop/)

## What this assumes
Your AMI already has:
- Docker Engine - minimally permissions for root
- Docker Compose plugin - minimally permissions for root
- `docker-compose.yml` (provided) placed at `/opt/juiceshop/docker-compose.yml`
- Docker service enabled on boot (`systemctl enable docker`)

`user_data` just runs `docker compose up -d` on boot, so a reboot or instance
replacement brings Juice Shop back automatically.

## Sizing rationale (root volume)
- Base OS (Ubuntu/AL2): ~1.5–3 GB
- Docker engine + image layers: ~1 GB
- `bkimminich/juice-shop` image: ~250–300 MB
- Runtime data (sqlite db, uploads, logs, CTF artifacts): grows slowly, usually well under 1 GB even under heavy use
- Docker log rotation, apt cache, misc: ~1–2 GB

## Usage
Drop this into a `terraform.tfvars` file:
```hcl
aws_region        = "us-east-2"
ami_id            = "ami-xxxxxxxxxxxxxxxxx"
route53_zone_name = "example.com"  # your existing Route 53 hosted zone
subdomain         = "juiceshop"    # -> juiceshop-<student>.example.com

students = [
  "maryam",
  "amina",
  "adam",
]
```

Then:
```bash
terraform init
terraform apply
```

After apply:
- `dns_names` / `juice_shop_dns_urls` — maps of student name -> subdomain/URL
- `static_ips` / `juice_shop_urls` — maps of student name -> Elastic IP/URL

Each student gets their own instance, Elastic IP, and DNS record:
`juiceshop-maryam.example.com`, `juiceshop-amina.example.com`, etc.

# Things I'd Like

- TLS
- EC2 Image Builder
- Controlllllll plane