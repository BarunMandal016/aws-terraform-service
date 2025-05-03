terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.89.0"
    }
  }
}

provider "aws" {
  # Configuration options
  region = "us-east-1"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "iam_for_lambda" {
  name               = "iam_for_lambda"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "lambda.mjs"
  output_path = "lambda_function_payload.zip"
}

resource "aws_lambda_function" "test_lambda" {
  # If the file is not in the current working directory you will need to include a
  # path.module in the filename.
  filename      = "lambda_function_payload.zip"
  function_name = "lambda_function_name_from_terraform"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "lambda.handler"

  source_code_hash = data.archive_file.lambda.output_base64sha256

  runtime = "nodejs22.x"

  environment {
    variables = {
      slack = "bot-token-has-changed"
    }
  }


  layers = [aws_lambda_layer_version.lambda_layer.arn]
}

# Create a zip file for the axios layer
data "archive_file" "axios_layer" {
  type        = "zip"
  source_dir = "./axioslayer"
  output_path = "lambda_layer_payload.zip"
}

resource "aws_lambda_layer_version" "lambda_layer" {
  filename            = data.archive_file.axios_layer.output_path
  layer_name          = "lambda_layer_axios"
  compatible_runtimes = ["nodejs22.x"]
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]

    resources = [
      "arn:aws:s3:::dummy-021/*",
    ]
  }
  
}

resource "aws_iam_policy" "policy" {
  name        = "s3_read_policy"
  description = "This policy allows read access to S3 buckets"
  policy = data.aws_iam_policy_document.s3_policy.json
}