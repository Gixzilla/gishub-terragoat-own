module "s3_bucket" {
  source                   = "../../../modules/s3"
  buckets                  = var.buckets 
}