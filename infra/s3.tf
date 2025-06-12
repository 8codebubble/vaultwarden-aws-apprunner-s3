# Define bucket name as a variable
variable "bucket_name" {
  default = "vaultwarden-aws-apprunner-s3-bucket"
}

resource "aws_s3_bucket" "vaultwarden_s3" {
   bucket = var.bucket_name 
  #bucket = "vaultwarden-storage-${random_string.suffix.result}"
}

#resource "random_string" "suffix" {
#  length  = 6
#  special = false
#  upper   = false
#}

# Enable versioning for object tracking
resource "aws_s3_bucket_versioning" "versioning" {
  bucket = aws_s3_bucket.vaultwarden_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

# Restrict public access
#resource "aws_s3_bucket_public_access_block" "public_access" {
#  bucket                  = aws_s3_bucket.vaultwarden_s3.id
#  block_public_acls       = true
#  block_public_policy     = true
#  ignore_public_acls      = true
#  restrict_public_buckets = true
#}


# Output bucket name
output "s3_bucket_name" {
  value = aws_s3_bucket.vaultwarden_s3.bucket
}
