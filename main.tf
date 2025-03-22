terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "4.52.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.4.3"
    }
  }
  required_version = ">= 1.1.0"

  cloud {
    organization = "hugo-organization"

    workspaces {
      name = "learn-terraform-github-actions"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# # Role para a Lambda
# resource "aws_iam_role" "lambda_role" {
#   name = "lambda_execution_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }

# Política de permissões para logs e acesso à VPC
resource "aws_iam_policy_attachment" "lambda_logs" {
  name       = "lambda_logs"
  roles      = ["LabRole"]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Empacotamento do código da Lambda (assumindo que está em "lambda_code/index.js")
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "lambda.zip"

  source {
    content  = file("../src/index.mjs") # Caminho do código da Lambda
    filename = "index.mjs"
  }
}

# Recurso AWS Lambda
resource "aws_lambda_function" "http_lambda" {
  filename         = data.archive_file.lambda_zip.output_path
  function_name    = "http_lambda"
  role             = aws_iam_role.lambda_role.arn
  handler          = "index.lambdaHandler"
  runtime          = "nodejs18.x"
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  environment {
    variables = {
      DB_HOST   = "seu-host-mysql"
      DB_USER   = "seu-usuario"
      DB_PASSWORD = "sua-senha"
      DB_NAME   = "seu-banco"
      DB_PORT   = "3306"
      X_API_KEY = "sua-chave-api"
    }
  }
}

# API Gateway REST API
resource "aws_api_gateway_rest_api" "api" {
  name        = "lambda_http_api"
  description = "API Gateway para Lambda HTTP"
}

# API Gateway Resource
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "lambda"
}

# API Gateway Método (POST)
resource "aws_api_gateway_method" "method" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Integração API Gateway -> Lambda
resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.resource.id
  http_method             = aws_api_gateway_method.method.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.http_lambda.invoke_arn
}

# Permissão para API Gateway chamar a Lambda
resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.http_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/*"
}

# Deploy da API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  depends_on  = [aws_api_gateway_integration.integration]
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name  = "prod"
}

# Saída com a URL de acesso
output "invoke_url" {
  value = "${aws_api_gateway_deployment.deployment.invoke_url}/lambda"
}