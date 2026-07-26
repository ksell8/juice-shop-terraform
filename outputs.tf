output "instance_ids" {
  description = "Instance ID per student"
  value       = { for k, v in aws_instance.juiceshop : k => v.id }
}

output "static_ips" {
  description = "Elastic IP per student"
  value       = { for k, v in aws_eip.juiceshop : k => v.public_ip }
}

output "juice_shop_urls" {
  description = "URL per student, by static IP"
  value       = { for k, v in aws_eip.juiceshop : k => "http://${v.public_ip}:3000" }
}

output "dns_names" {
  description = "DNS name per student"
  value       = { for k, v in aws_route53_record.juiceshop : k => v.fqdn }
}

output "juice_shop_dns_urls" {
  description = "URL per student, by DNS name"
  value       = { for k, v in aws_route53_record.juiceshop : k => "http://${v.fqdn}:3000" }
}
