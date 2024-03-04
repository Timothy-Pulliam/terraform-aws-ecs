# About

This project creates an ECS instance based on a container image URI and creates the necessary infrastructure for it to run.

- private VPC/Subnet
- ECS Cluster, Task Definition and Service Definition
- private endpoints for
  - ECR API
  - ECR Docker
  - Cloud Watch Logs
  - S3 (needed to pull docker image layers)
- Security Groups
- Task Execution Role

![](/tfstate.png)

## Requirements

| Name                                                                     | Version  |
| ------------------------------------------------------------------------ | -------- |
| <a name="requirement_terraform"></a> [terraform](#requirement_terraform) | >= 1.7.4 |
| <a name="requirement_aws"></a> [aws](#requirement_aws)                   | ~> 5.0   |

## Providers

| Name                                             | Version |
| ------------------------------------------------ | ------- |
| <a name="provider_aws"></a> [aws](#provider_aws) | 5.39.0  |

## Modules

No modules.

## Resources

| Name                                                                                                                                                                        | Type     |
| --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- |
| [aws_cloudwatch_log_group.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group)                                           | resource |
| [aws_ecs_cluster.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_cluster)                                                             | resource |
| [aws_ecs_service.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_service)                                                             | resource |
| [aws_ecs_task_definition.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecs_task_definition)                                             | resource |
| [aws_iam_role.ecs_task_execution_role_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role)                                     | resource |
| [aws_iam_role_policy_attachment.ecs_task_execution_role_attachment](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_security_group.allow_https_in](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                             | resource |
| [aws_security_group.ecs_service_sg](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/security_group)                                             | resource |
| [aws_service_discovery_http_namespace.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/service_discovery_http_namespace)                   | resource |
| [aws_subnet.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/subnet)                                                                       | resource |
| [aws_vpc.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)                                                                             | resource |
| [aws_vpc_endpoint.cloudwatch_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)                                            | resource |
| [aws_vpc_endpoint.ecr_api](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)                                                        | resource |
| [aws_vpc_endpoint.ecr_dkr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)                                                        | resource |
| [aws_vpc_endpoint.s3_endpoint](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc_endpoint)                                                    | resource |

## Inputs

| Name                                                                                                   | Description                                                                                                                                                               | Type     | Default       | Required |
| ------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ------------- | :------: |
| <a name="input_app_name"></a> [app_name](#input_app_name)                                              | Name of Elastic Container Registry                                                                                                                                        | `string` | `"myapp"`     |    no    |
| <a name="input_cloudwatch_skip_destroy"></a> [cloudwatch_skip_destroy](#input_cloudwatch_skip_destroy) | Set to true if you do not wish the log group (and any logs it may contain) to be deleted at destroy time, and instead just remove the log group from the Terraform state. | `bool`   | `true`        |    no    |
| <a name="input_docker_image_uri"></a> [docker_image_uri](#input_docker_image_uri)                      | Docker Image URI to be used                                                                                                                                               | `string` | n/a           |   yes    |
| <a name="input_region"></a> [region](#input_region)                                                    | AWS Region                                                                                                                                                                | `string` | `"us-east-1"` |    no    |

## Outputs

No outputs.

# Cost Breakdown

```
tpulliam@lappy terraform-ecs % make cost
infracost breakdown --path . --usage-file infracost-usage.yml  --sync-usage-file --show-skipped
Evaluating Terraform directory at .
  ✔ Downloading Terraform modules
  ✔ Evaluating Terraform directory
  ✔ Syncing usage data from cloud
    └─ Synced 0 of 15 resources
  ✔ Downloading Terraform modules
  ✔ Evaluating Terraform directory
  ✔ Retrieving cloud prices to calculate costs

Project: .

 Name                                     Monthly Qty  Unit              Monthly Cost

 aws_cloudwatch_log_group.this
 ├─ Data ingested                      Monthly cost depends on usage: $0.50 per GB
 ├─ Archival Storage                   Monthly cost depends on usage: $0.03 per GB
 └─ Insights queries data scanned      Monthly cost depends on usage: $0.005 per GB

 aws_ecs_service.this
 ├─ Per GB per hour                                 2  GB                       $6.49
 └─ Per vCPU per hour                               1  CPU                     $29.55

 aws_vpc_endpoint.cloudwatch_endpoint
 ├─ Data processed (first 1PB)         Monthly cost depends on usage: $0.01 per GB
 └─ Endpoint (Interface)                          730  hours                    $7.30

 aws_vpc_endpoint.ecr_api
 ├─ Data processed (first 1PB)         Monthly cost depends on usage: $0.01 per GB
 └─ Endpoint (Interface)                          730  hours                    $7.30

 aws_vpc_endpoint.ecr_dkr
 ├─ Data processed (first 1PB)         Monthly cost depends on usage: $0.01 per GB
 └─ Endpoint (Interface)                          730  hours                    $7.30

 OVERALL TOTAL                                                                 $57.94
──────────────────────────────────
15 cloud resources were detected:
∙ 5 were estimated, 4 of which include usage-based costs, see https://infracost.io/usage-file
∙ 9 were free:
  ∙ 2 x aws_security_group
  ∙ 1 x aws_ecs_cluster
  ∙ 1 x aws_ecs_task_definition
  ∙ 1 x aws_iam_role
  ∙ 1 x aws_iam_role_policy_attachment
  ∙ 1 x aws_subnet
  ∙ 1 x aws_vpc
  ∙ 1 x aws_vpc_endpoint
∙ 1 is not supported yet, see https://infracost.io/requested-resources:
  ∙ 1 x aws_service_discovery_http_namespace

┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┳━━━━━━━━━━━━━━┓
┃ Project                                            ┃ Monthly cost ┃
┣━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━╋━━━━━━━━━━━━━━┫
┃ .                                                  ┃ $58          ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┻━━━━━━━━━━━━━━┛
```
