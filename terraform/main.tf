variable "buckets" {
  type = map(object({
    bucket_name = string
    environment = string
  }))
}

locals {
test_metadata = {
api_key = "XVGYUhyauety23899ajjjagGGGG"
username = "demo"
}
}

resource "aws_s3_bucket" "my_bucket" {
  for_each = var.buckets

  bucket = each.value.bucket_name
  
  tags = {
    Name        = each.value.bucket_name
    Environment = each.value.environment
    test        = "hello"
  }

  lifecycle {
    ignore_changes = [tags]
  }
}
