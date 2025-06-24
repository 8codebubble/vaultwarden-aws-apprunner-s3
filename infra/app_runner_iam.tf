resource "aws_iam_role" "apprunner_execution_role" {
  name = "vaultwarden-apprunner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = ["tasks.apprunner.amazonaws.com", "build.apprunner.amazonaws.com"]
      },
      Action = "sts:AssumeRole"
    }]
  })
}

# Attach ECR access policy (Updated with correct permissions)
resource "aws_iam_policy" "apprunner_ecr_pull_policy" {
  name        = "apprunner-ecr-pull-policy"
  description = "Allows App Runner to pull images from ECR"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = [
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchCheckLayerAvailability",
        "ecr:BatchGetImage",
        "ecr:DescribeImages",
        "ecr:GetAuthorizationToken"
      ],
      Resource = "*"
    }]
  })
}

# Attach S3 access policy for Vaultwarden
resource "aws_iam_policy" "vaultwarden_s3_access" {
  name        = "vaultwarden-s3-access-policy"
  description = "Allows App Runner to access S3 bucket"
  
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["s3:GetObject", "s3:PutObject", "s3:ListBucket","s3:DeleteObject"],
      Resource = [
        aws_s3_bucket.vaultwarden_s3.arn,
        "${aws_s3_bucket.vaultwarden_s3.arn}/*"
      ]
    },
    {
        Effect   = "Allow",
        Action   = ["s3:ListBucket","s3:GetBucketLocation"],
        Resource = "${aws_s3_bucket.vaultwarden_s3.arn}"
      }
    ]
  })
}

resource "aws_iam_policy" "vaultwarden_parameterstore_access" {
  name        = "vaultwarden-ssm-parameter-access"
  description = "Allows App Runner to access SSM parameters for S3 keys"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["ssm:GetParameter", "ssm:GetParameters", "ssm:GetParameterHistory"],
        Resource = [
          aws_ssm_parameter.vaultwarden_access_key_id.arn,
          aws_ssm_parameter.vaultwarden_secret_access_key.arn,
          aws_ssm_parameter.vaultwarden_bucket_name.arn,
          aws_ssm_parameter.vaultwarden_data_folder.arn,
          aws_ssm_parameter.vaultwarden_admin_token.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vaultwarden_parameterstore_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.vaultwarden_parameterstore_access.arn
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_pull_policy_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.apprunner_ecr_pull_policy.arn
}

resource "aws_iam_role_policy_attachment" "vaultwarden_s3_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.vaultwarden_s3_access.arn
}


###############################################################################
# Create IAM User for Vaultwarden S3 access
###############################################################################
resource "aws_iam_user" "vaultwarden_user" {
  name = "vaultwarden-apprunner-user"
}

resource "aws_iam_access_key" "vaultwarden_keys" {
  user = aws_iam_user.vaultwarden_user.name
}

# Attach S3 access policy to IAM User
resource "aws_iam_user_policy_attachment" "vaultwarden_s3_attach" {
  user       = aws_iam_user.vaultwarden_user.name
  policy_arn = aws_iam_policy.vaultwarden_s3_access.arn
}

###############################################################################


# Create SSM Parameter for Vaultwarden S3 Access Key ID
resource "aws_ssm_parameter" "vaultwarden_access_key_id" {
  name        = "/vaultwarden/s3/access_key_id"
  type        = "SecureString"
  value       = aws_iam_access_key.vaultwarden_keys.id
  description = "Vaultwarden S3 user access key ID"
  overwrite    = true  
}
# Create SSM Parameter for Vaultwarden S3 Access Key ID
resource "aws_ssm_parameter" "vaultwarden_secret_access_key" {
  name        = "/vaultwarden/s3/secret_access_key"
  type        = "SecureString"
  value       = aws_iam_access_key.vaultwarden_keys.secret
  description = "Vaultwarden S3 user secret access key"
  overwrite    = true
}
resource "aws_ssm_parameter" "vaultwarden_bucket_name" {
  name        = "/vaultwarden/s3/bucket_name"
  type        = "SecureString"
  value       = aws_s3_bucket.vaultwarden_s3.bucket # Use the bucket name from the S3 bucket resource Located in s3.tf
  description = "Vaultwarden S3 bucket name"
  overwrite    = true
}
resource "aws_ssm_parameter" "vaultwarden_data_folder" {
  name        = "/vaultwarden/data_folder"
  type        = "SecureString"
  value       = "/tmp/vaultwarden/data" # This is the data folder used by Vaultwarden in App Runner
  description = "Vaultwarden data folder"
  overwrite    = true
}

resource "aws_ssm_parameter" "vaultwarden_admin_token" {
  name        = "/vaultwarden/admin_token"
  type        = "SecureString"
  value       = "your_admin_token_value" #this will be replacesd in the github action that pull the secret from the repository secrets
  description = "Vaultwarden admin token"
  overwrite    = true
}
resource "aws_ssm_parameter" "vaultwarden_aws_region" {  
  name        = "/vaultwarden/aws_region"
  type        = "String"
  value       = var.aws_region # Use the region from the AWS provider
  description = "Vaultwarden S3 bucket region"
  overwrite    = true
}
resource "aws_ssm_parameter" "vaultwarden_s3_endpoint" {
  name        = "/vaultwarden/s3/endpoint"
  type        = "String"
  value       = "s3.${var.aws_region}.amazonaws.com"
  description = "Vaultwarden S3 bucket endpoint"
  overwrite    = true
}



