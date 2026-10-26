variable "aws_region" {
  description = "The AWS region to deploy resources in"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  type        = string
  default     = "serverless-inference-framework"
  description = "Prefix applied to all created resource name tags."
}

variable "image_tag" {
  type        = string
  description = "Tag of the inference image in the ECR repository (must be unique per build; tags are immutable)."
}

variable "availability_zone" {
  description = "The AWS availability zone to deploy resources in"
  type        = string
  default     = "ap-south-1a"
}

variable "container_vcpu" {
  type        = string
  default     = "4.0"
  description = "The number of vCPUs to allocate to the inference container. Higher allocations unlock higher network throughput for s5cmd downloads."
}

variable "container_memory" {
  type        = string
  default     = "8192"
  description = "The amount of memory (in MiB) to allocate to the container (e.g., 8192 for 8GB RAM)."
}
