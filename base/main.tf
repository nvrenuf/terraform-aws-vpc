# VPC base

## Set Terraform version constraint
terraform {
  required_version = "> 0.8.0"
}

## Provisions Virtual Private Cloud (VPC)
resource "aws_vpc" "vpc" {
  cidr_block           = "${var.vpc_cidr}"
  instance_tenancy     = "${var.instance_tenancy}"
  enable_dns_support   = "${var.enable_dns}"
  enable_dns_hostnames = "${var.enable_hostnames}"
  enable_classiclink   = "${var.enable_classiclink}"

  tags {
    application = "${var.stack_item_fullname}"
    managed_by  = "terraform"
    Name        = "${var.stack_item_label}-vpc"
  }
}

## Provisions Internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = "${aws_vpc.vpc.id}"

  tags {
    application = "${var.stack_item_fullname}"
    managed_by  = "terraform"
    Name        = "${var.stack_item_label}-igw"
  }
}

## Provisions DMZ routing table
resource "aws_route_table" "rt_dmz" {
  propagating_vgws = ["${compact(var.vgw_ids)}"]
  vpc_id           = "${aws_vpc.vpc.id}"

  tags {
    application = "${var.stack_item_fullname}"
    managed_by  = "terraform"
    Name        = "${var.stack_item_label}-dmz"
  }
}

## Provisions VPC flow logs
resource "aws_cloudwatch_log_group" "flow_log_group" {
  name = "${var.stack_item_label}-vpc-flow-logs"
}

resource "aws_iam_role" "flow_log_role" {
  name = "${var.stack_item_label}-vpc-flow-logs"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Principal": {
      "Service": "vpc-flow-logs.amazonaws.com"
    },
    "Effect": "Allow"
  }]
}
EOF
}

resource "aws_iam_role_policy" "flow_log_role_policies" {
  name = "logs"
  role = "${aws_iam_role.flow_log_role.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents",
      "logs:DescribeLogGroups",
      "logs:DescribeLogStreams"
    ],
    "Effect": "Allow",
    "Resource": "${aws_cloudwatch_log_group.flow_log_group.arn}"
  }]
}
EOF
}

resource "aws_flow_log" "flow_log" {
  log_group_name = "${var.stack_item_label}-vpc-flow-logs"
  iam_role_arn   = "${aws_iam_role.flow_log_role.arn}"
  vpc_id         = "${aws_vpc.vpc.id}"
  traffic_type   = "${var.flow_log_traffic_type}"
}
