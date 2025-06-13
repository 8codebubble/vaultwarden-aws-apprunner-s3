resource "aws_iam_user" "vaultwarden_user" {
  name = "vaultwarden-apprunner-user"
}

resource "aws_iam_access_key" "vaultwarden_keys" {
  user = aws_iam_user.vaultwarden_user.name
}

resource "aws_secretsmanager_secret" "vaultwarden_s3_user_access_key_id" {
  name = "vaultwarden-s3-user-access-key-id"
}
resource "aws_secretsmanager_secret_version" "vaultwarden_s3_user_access_key_id_value" {
  secret_id     = aws_secretsmanager_secret.vaultwarden_s3_user_access_key_id.id
  secret_string =  aws_iam_access_key.vaultwarden_keys.id
}

resource "aws_secretsmanager_secret" "vaultwarden_s3_user_secret_access_key" {
  name = "vaultwarden-s3-user-secret-access-key"
}
resource "aws_secretsmanager_secret_version" "vaultwarden_s3_user_secret_access_key_value" {
  secret_id     = aws_secretsmanager_secret.vaultwarden_s3_user_secret_access_key.id
  secret_string =  aws_iam_access_key.vaultwarden_keys.secret
}

# Attach S3 access policy to IAM User
resource "aws_iam_user_policy_attachment" "vaultwarden_s3_attach" {
  user       = aws_iam_user.vaultwarden_user.name
  policy_arn = aws_iam_policy.vaultwarden_s3_access.arn
}
