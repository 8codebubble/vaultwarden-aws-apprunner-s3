resource "aws_iam_role" "vaultwarden_apprunner_role" {
  name = "vaultwarden-apprunner-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Service = "tasks.apprunner.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "vaultwarden_s3_attach" {
  role       = aws_iam_role.vaultwarden_apprunner_role.name
  policy_arn = aws_iam_policy.vaultwarden_s3_access.arn
}
