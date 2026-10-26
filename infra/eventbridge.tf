resource "aws_s3_bucket_notification" "data_bucket_events" {
  bucket      = aws_s3_bucket.data_bucket.id
  eventbridge = true
}

resource "aws_cloudwatch_event_rule" "input_uploaded" {
  name        = "${var.project_name}-input-uploaded"
  description = "Submit an inference job when a .txt file lands in input/"

  event_pattern = jsonencode({
    source        = ["aws.s3"]
    "detail-type" = ["Object Created"]
    detail = {
      bucket = { name = [aws_s3_bucket.data_bucket.id] }
      object = { key = [{ prefix = "input/" }, { suffix = ".txt" }] }
    }
  })
}

resource "aws_iam_role" "eventbridge_submit_job_role" {
  name = "${var.project_name}-eventbridge-submit-job-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { Service = "events.amazonaws.com" }
        Action    = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "eventbridge_submit_job" {
  name = "${var.project_name}-submit-job"
  role = aws_iam_role.eventbridge_submit_job_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = "batch:SubmitJob"
        Resource = [
          aws_batch_job_queue.inference_queue.arn,
          "${aws_batch_job_definition.inference_job.arn_prefix}:*"
        ]
      }
    ]
  })
}

resource "aws_cloudwatch_event_target" "submit_batch_job" {
  rule     = aws_cloudwatch_event_rule.input_uploaded.name
  arn      = aws_batch_job_queue.inference_queue.arn
  role_arn = aws_iam_role.eventbridge_submit_job_role.arn

  batch_target {
    job_definition = aws_batch_job_definition.inference_job.arn
    job_name       = "${var.project_name}-inference"
  }

  input_transformer {
    input_paths = { key = "$.detail.object.key" }
    # Not jsonencode: it escapes < and > to </>, which breaks EventBridge's <key> placeholder.
    input_template = <<-EOT
      {"ContainerOverrides":{"Environment":[{"Name":"INPUT_KEY","Value":"<key>"}]}}
    EOT
  }
}
