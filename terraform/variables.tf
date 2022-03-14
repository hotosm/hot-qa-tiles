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

variable "git_commit_sha" {
  type    = string
  default = "3fdb96cfa274ed591bea36fcb031e4d872d175ff"
}

// Fetch from Terraform
variable "oauth_token" {
  type    = string
  default = ""
}

variable "s3_destination_path" {
  type    = string
  default = ""
}

variable "project_name" {
  type    = string
  default = "qa-tiles"
}

variable "aws_region" {
  type    = string
  default = "us-west-1"
}

variable "ssh_key_name" {
  type    = string
  default = "mbtiles"
}
