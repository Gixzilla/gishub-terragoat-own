##s3##

variable "buckets" {
  type = map(object({
    bucket_name = string
    environment = string
    block_public_acls = bool
    block_public_policy = bool
    ignore_public_acls = bool
    restrict_public_buckets = bool
    bucket_versioning = string
    enable_public_access_block = bool
    policy = string
    lifecycle_expiration_days   = number
    lifecycle_noncurrent_days   = number
    abort_multipart_days = number
    kms_key_id = string
    enable_access_logging = bool
    logging_bucket = string
    notification_queue_arn = string
    crr_bucket = string
  }))
}