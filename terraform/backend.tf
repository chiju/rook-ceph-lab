# S3 backend with native state locking (no DynamoDB needed)
# For GitHub Actions with OIDC - no profile needed
terraform {
  backend "s3" {
    bucket       = "eks-gitops-tfstate-93fbef90"
    key          = "rook-ceph-lab.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}
