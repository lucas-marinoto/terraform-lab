variable "application_name" {
  description = "Application name used in ECS resources."
  type        = string
  default     = "nebula-api"
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "dev"
}

variable "image_uri" {
  description = "Immutable ECR image URI, preferably repository@sha256:digest."
  type        = string
}

variable "subnet_ids" {
  description = "Private subnet IDs used by the ECS service."
  type        = list(string)
}

variable "security_group_ids" {
  description = "Security group IDs attached to ECS tasks."
  type        = list(string)
}

variable "execution_role_arn" {
  description = "ECS task execution role ARN."
  type        = string
}

variable "task_role_arn" {
  description = "Optional ECS task role ARN used by the application."
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Number of ECS tasks."
  type        = number
  default     = 1
}

variable "cpu" {
  description = "Fargate CPU units."
  type        = number
  default     = 256
}

variable "memory" {
  description = "Fargate memory in MiB."
  type        = number
  default     = 512
}
