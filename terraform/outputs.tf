output "bucket_name" {
  value = [for b in aws_s3_bucket.my_bucket : b.bucket]
}

output "bucket_arns" {
  value = { for k, b in aws_s3_bucket.my_bucket : k => b.arn }
}
