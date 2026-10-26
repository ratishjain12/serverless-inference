output "input_data_bucket" {
  value       = aws_s3_bucket.data_bucket.id
  description = "Standard S3 storage vault for tracking inputs and processed files."
}

output "model_weights_bucket" {
  value       = aws_s3_bucket.model_bucket.id
  description = "Standard S3 caching directory path where model parameter sub-directories are stored."
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.inference_repo.repository_url
  description = "ECR repository URL to push the inference image to."
}

output "batch_job_queue_arn" {
  value       = aws_batch_job_queue.inference_queue.arn
  description = "The Amazon Resource Name (ARN) of the processing target pipeline queue."
}

output "batch_job_definition_arn" {
  value       = aws_batch_job_definition.inference_job.arn
  description = "The Amazon Resource Name (ARN) of the baseline template job specification."
}
