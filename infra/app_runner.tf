# Create App Runner service
resource "aws_apprunner_service" "vaultwarden" {
  service_name = "vaultwarden-apprunner"
  source_configuration {
    image_repository {
      image_configuration {
        port = "8080"  # Port that the application listens on
        runtime_environment_variables = {
          ROCKET_PORT = "8080"
          ROCKET_ADDRESS = "0.0.0.0"
          #DATABASE_URL = "postgres://user:password@db.example.com:5432/vaultwarden"
          #ADMIN_TOKEN = "khjgasdhjgrew"
          #DATA_FOLDER = "/tmp/vaultwarden/data"
        }
        # Secrets from AWS credentials
        runtime_environment_secrets = {
          AWS_ACCESS_KEY_ID     = aws_ssm_parameter.vaultwarden_access_key_id.arn
          AWS_SECRET_ACCESS_KEY = aws_ssm_parameter.vaultwarden_secret_access_key.arn
          S3_BUCKET_NAME        = aws_ssm_parameter.vaultwarden_bucket_name.arn
          DATA_FOLDER           = aws_ssm_parameter.vaultwarden_data_folder.arn
          ADMIN_TOKEN           = aws_ssm_parameter.vaultwarden_admin_token.arn
          S3_ENDPOINT           = aws_ssm_parameter.vaultwarden_s3_endpoint.arn
          AWS_REGION             = aws_ssm_parameter.vaultwarden_aws_region.arn
          ############# Add more secrets here and define them in app_runner_iam.tf
          }

      }
      image_identifier = "${aws_ecr_repository.vaultwarden_app_runner_repo.repository_url}:latest" #"YOUR_ECR_REPOSITORY_URL:latest"
      image_repository_type = "ECR"
    }
    authentication_configuration {
      access_role_arn = aws_iam_role.apprunner_execution_role.arn
    }
    auto_deployments_enabled = false  # Disables automatic deployments
    
    
  }
  
  instance_configuration {
    cpu    = "0.25 vCPU"
    memory = "0.5 GB"
    instance_role_arn = aws_iam_role.apprunner_execution_role.arn
    
  }
  # Define health check configuration    
    health_check_configuration {
      protocol            = "HTTP"
      path                = "/alive"
      interval            = 20    # Check every 5 seconds
      timeout             = 2    # Fail if no response within 2 seconds
      healthy_threshold   = 1    # Mark healthy after 1 successful check
      unhealthy_threshold = 3    # Mark unhealthy after 3 failed checks
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
