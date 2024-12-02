output "generated_policy" {
  value = aws_ecr_repository_policy.appointment_service_repo_policy.policy
}
