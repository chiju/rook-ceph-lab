# S3 backend with native state locking (no DynamoDB needed)
# For GitHub Actions with OIDC - no profile needed
terraform {
  backend "s3" {
    bucket       = "eks-gitops-tfstate-f2851984"
    key          = "eks-gitops-lab.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
