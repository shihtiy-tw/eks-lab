provider "aws" {
  region = terraform.workspace
}

# Fetch the existing Route53 zone
data "aws_route53_zone" "existing_zone" {
  name = var.domain_name
}


# Create a public ACM certificate
resource "aws_acm_certificate" "public_cert" {
  domain_name       = "*.${var.domain_name}"
  validation_method = "DNS"
}

# Create a Route53 record for certificate validation
resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.public_cert.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }
  allow_overwrite = true
  name            = each.value.name
  records         = [each.value.record]
  ttl             = 60
  type            = each.value.type
  zone_id         = data.aws_route53_zone.existing_zone.zone_id
}

# Validate the ACM certificate
resource "aws_acm_certificate_validation" "cert_validation" {
  certificate_arn         = aws_acm_certificate.public_cert.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}
