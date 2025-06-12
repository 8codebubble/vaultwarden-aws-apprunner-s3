resource "aws_iam_policy" "vaultwarden_s3_access" {
  name        = "vaultwarden-s3-access-policy"
  description = "Allows App Runner to access S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"],
      Resource = [
        aws_s3_bucket.vaultwarden_s3.arn,
        "${aws_s3_bucket.vaultwarden_s3.arn}/*"
      ]
    }]
  })
}
