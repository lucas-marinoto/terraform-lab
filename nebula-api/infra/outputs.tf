output "ecs_cluster_name" {
  description = "Created ECS cluster name."
  value       = aws_ecs_cluster.this.name
}

output "ecs_service_name" {
  description = "Created ECS service name."
  value       = aws_ecs_service.app.name
}

output "task_definition_arn" {
  description = "Registered task definition ARN."
  value       = aws_ecs_task_definition.app.arn
}

output "deployed_image_uri" {
  description = "Immutable image URI deployed to ECS."
  value       = var.image_uri
}
