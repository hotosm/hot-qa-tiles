terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project       = "qa-tiles"
      Maintainer    = "Dakota_Benjamin and Yogesh_Girikumar"
      Documentation = "https://docs.hotosm.org/qa-tiles"
    }
  }
}

