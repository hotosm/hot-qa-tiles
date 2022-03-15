// Copyright (C) 2021 Humanitarian OpenStreetmap Team

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

// Humanitarian OpenStreetmap Team
// 1100 13th Street NW Suite 800 Washington, D.C. 20005
// <info@hotosm.org>

data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_autoscaling_group" "qa-tiles" {
  name                      = var.project_name
  max_size                  = 1
  min_size                  = 1
  health_check_grace_period = 300
  health_check_type         = "EC2"
  desired_capacity          = 1
  availability_zones        = data.aws_availability_zones.available
  default_cooldown          = "300"

  mixed_instances_policy {
    launch_template {
      launch_template_specification {
        launch_template_id = aws_launch_template.qa-tiles.id
      }

      override {
        instance_type     = "r5d.8xlarge"
        weighted_capacity = "3"
      }

      override {
        instance_type     = "r5dn.8xlarge"
        weighted_capacity = "2"
      }
    }

    instances_distribution {
      on_demand_base_capacity                  = 0
      on_demand_percentage_above_base_capacity = 50
      spot_allocation_strategy                 = "lowest-price"
      spot_instance_pools                      = 2
    }
  }

  tags = [
    {
      key                 = "Name"
      value               = "QA-Tiles"
      propagate_at_launch = true
    },
    {
      key                 = "Environment"
      value               = var.deployment_environment
      propagate_at_launch = true
    }
  ]
}

resource "aws_autoscaling_schedule" "qa-tiles" {
  name                   = var.project_name
  autoscaling_group_name = aws_autoscaling_group.qa-tiles.name
  desired_capacity       = 1
  max_size               = 1
  min_size               = 0
  recurrence             = "15 7 * * 2"
}

resource "aws_launch_template" "qa-tiles" {
  name = var.project_name

  instance_initiated_shutdown_behavior = "terminate"

  iam_instance_profile {
    arn      = aws_iam_instance_profile.qa-tiles.arn
    key_name = var.ssh_key_name
    image_id = data.aws_ami.amazon_linux_2.id

  }

  user_data = filebase64(
    templatefile(
      "${path.module}/bootstrap.tpl",
      {
        git_commit_sha      = var.git_commit_sha,
        oauth_token         = var.oauth_token,
        s3_destination_path = var.s3_destination_path
        asg_name            = var.project_name
        aws_region          = var.aws_region
      }
    )
  )

}

resource "aws_iam_instance_profile" "qa-tiles" {
  name = "${var.project_name}-profile"
  role = aws_iam_role.qa-tiles.name
}

data "aws_iam_policy_document" "assume-role-ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "qa-tiles" {
  statement {
    sid = "1"
    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "arn:aws:s3:::hot-qa-tiles",
      "arn:aws:s3:::hot-qa-tiles-test",
    ]
  }

  statement {
    sid = "2"


    actions = [
      "s3:GetObject",
      "s3:GetObjectAcl",
      "s3:PutObject",
      "s3:PutObjectAcl",
      "s3:ListObjects",
      "s3:DeleteObject"
    ]
    resources = [
      "arn:aws:s3:::hot-qa-tiles/*",
      "arn:aws:s3:::hot-qa-tiles-test/*",
    ]
  }
}

resource "aws_iam_role_policy_attachment" "qa-tiles" {
  role       = aws_iam_role.qa-tiles.name
  policy_arn = aws_iam_policy.deferred.arn
}

data "aws_iam_policy_document" "deferred" {
  statement {
    sid = "3"

    actions = [
      "autoscaling:UpdateAutoScalingGroup",
    ]
    resources = [
      aws_autoscaling_group.qa-tiles.arn,
    ]
  }

}

resource "aws_iam_policy" "deferred" {
  name        = "${var.project-name}-asg"
  path        = "/qa-tiles/"
  description = "QA Tiles AutoscalingGroup access"
  policy      = data.aws_iam_policy_document.deferred.json
}

resource "aws_iam_role" "qa-tiles" {
  name = var.project_name
  path = "/qa-tiles/"

  assume_role_policy = data.aws_iam_policy_document.assume-role-ec2.json

  inline_policy {
    name   = var.project_name
    policy = data.aws_iam_policy_document.qa-tiles.json
  }
}

