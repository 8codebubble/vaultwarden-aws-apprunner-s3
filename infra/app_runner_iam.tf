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

resource "aws_iam_policy" "vaultwarden_secrets_access" {
  name        = "vaultwarden-secrets-access-policy"
  description = "Allows App Runner to access Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["secretsmanager:GetSecretValue"],
        Resource = [
          aws_secretsmanager_secret.vaultwarden_s3_user_access_key_id.arn,
          aws_secretsmanager_secret.vaultwarden_s3_user_secret_access_key.arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "vaultwarden_secrets_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.vaultwarden_secrets_access.arn
}

resource "aws_iam_role_policy_attachment" "apprunner_ecr_pull_policy_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.apprunner_ecr_pull_policy.arn
}

resource "aws_iam_role_policy_attachment" "vaultwarden_s3_attach" {
  role       = aws_iam_role.apprunner_execution_role.name
  policy_arn = aws_iam_policy.vaultwarden_s3_access.arn
}