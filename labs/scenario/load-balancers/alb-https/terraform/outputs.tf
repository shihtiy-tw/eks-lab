output "acm_certificate_arn" {
  description = "The ARN of the created ACM certificate"
  value       = aws_acm_certificate.public_cert.arn
}

output "route53_zone_id" {
  description = "The ID of the existing Route53 zone"
  value       = data.aws_route53_zone.existing_zone.id
}
