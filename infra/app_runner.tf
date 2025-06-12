# Create App Runner service
resource "aws_apprunner_service" "vaultwarden" {
  service_name = "vaultwarden-apprunner"
  source_configuration {
    image_repository {
      image_identifier = "${aws_ecr_repository.vaultwarden_app_runner_repo.repository_url}:latest" #"YOUR_ECR_REPOSITORY_URL:latest"
      image_repository_type = "ECR"
    }
  }

  instance_configuration {
    cpu    = "0.5 vCPU"
    memory = "1 GB"
  }

  # Enable auto-scaling to zero
  auto_scaling_configuration_arn = aws_apprunner_auto_scaling_configuration.vaultwarden_autoscaling.arn
}

# Define Auto Scaling Config
resource "aws_apprunner_auto_scaling_configuration" "vaultwarden_autoscaling" {
  auto_scaling_configuration_name = "vaultwarden-autoscaling"
  max_concurrency                 = 1
  max_size                        = 1   # Maximum of 1 running container
  min_size                        = 0   # Scale to zero when idle
}
