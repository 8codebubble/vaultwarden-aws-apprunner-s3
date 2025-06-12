# Create App Runner service
resource "aws_apprunner_service" "vaultwarden" {
  service_name = "vaultwarden-apprunner"
  source_configuration {
    image_repository {
      image_identifier = "${aws_ecr_repository.vaultwarden_app_runner_repo.repository_url}:latest" #"YOUR_ECR_REPOSITORY_URL:latest"
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.vaultwarden_apprunner_role.arn
    }
  }

  instance_configuration {
    cpu    = "0.5 vCPU"
    memory = "1 GB"
  }

  # Enable auto-scaling to zero
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration_version.vaultwarden_autoscaling.arn
}

# Define Auto Scaling Config
resource "aws_apprunner_auto_scaling_configuration_version" "vaultwarden_autoscaling" {
  auto_scaling_configuration_name = "vaultwarden-autoscaling"
  max_concurrency                 = 200
  max_size                        = 1   # Maximum of 1 running container
  min_size                        = 1   # Scale to zero when idle # does not seem to scale to zero.
}
