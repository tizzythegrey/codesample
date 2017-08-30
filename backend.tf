terraform {
  backend "s3" {}
}

# Run the command below to setup remote backend
#terraform init -backend-config="bucket=mycodesample-infrastructure" -backend-config="key=terraform.tfstate" -backend-config="region=us-west-2" -backend=true -force-copy -get=true -input=false
