terraform {
  backend "s3" {
    bucket = "derive-tf-state-bucket"
    key    = "tf-state-files/derive-cloud-baseline.tfstate"
    region = "us-west-1"
  }
}

provider "aws" {
  region = "us-west-1"
}
