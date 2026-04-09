# Walkthrough — AWS VPC Security Lab CI/CD Pipeline

This document describes the exact process followed to build this lab, phase by phase — what was done, why each decision was made, and what commands were executed. It serves as a reference for reproducing the lab or understanding the reasoning behind each step.

---

## Starting Point

The base for this lab was the [AWS VPC Security Lab](../aws-vpc-security-lab/) — a three-tier network segmentation architecture provisioned with Terraform that had already been validated end-to-end. The Terraform code was functional but structured as a flat collection of `.tf` files in a single directory, with some hardcoded values and local state.

The goal was to take that working infrastructure and wrap it in a production-grade CI/CD pipeline with automated security validation.

---

## Phase 0 — Refactoring the Terraform Module

### Why this was necessary

Before building any pipeline, the Terraform code needed to be restructured. A pipeline that runs `terraform apply` against a flat, hardcoded configuration is not reusable or environment-aware. The refactor had three goals:

1. Convert the flat code into a reusable **Terraform module**
2. Eliminate all hardcoded values — especially CIDRs and the authorized SSH IP
3. Introduce an **environment layer** that consumes the module with environment-specific inputs

### What was hardcoded

Reviewing the original code revealed:
- VPC CIDR (`10.0.0.0/16`) hardcoded in `vpc.tf`
- All subnet CIDRs hardcoded in `subnets.tf`
- App subnet CIDRs **repeated** in `nacls.tf` — meaning a CIDR change required updating two files
- EC2 key pair name hardcoded as a string in `ec2.tf`
- Authorized SSH IP set as a `default` value in `variables.tf` — visible in the repository

### New structure

```
aws-vpc-security-lab-cicd/
├── modules/
│   └── vpc-security/       ← all infrastructure logic lives here
│       ├── main.tf          ← VPC resource and shared locals
│       ├── variables.tf     ← all module inputs with validation
│       ├── subnets.tf       ← CIDRs read from variables
│       ├── routing.tf       ← IGW, NAT, route tables
│       ├── security-groups.tf
│       ├── nacls.tf         ← app subnet CIDRs from var.app_subnet_cidrs
│       ├── flow-logs.tf
│       ├── ec2.tf
│       └── outputs.tf
└── environments/
    └── dev/                ← instantiates the module for dev
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        ├── provider.tf
        └── backend.tf
```

### Key fix in nacls.tf

The most important change was in `nacls.tf`. The data layer NACL had the app subnet CIDRs written as literal strings:

```hcl
# Before — hardcoded, fragile
cidr_block = "10.0.11.0/24"
cidr_block = "10.0.12.0/24"
```

After the refactor, they reference the module variable:

```hcl
# After — dynamic, consistent with subnet definitions
cidr_block = var.app_subnet_cidrs[0]
cidr_block = var.app_subnet_cidrs[1]
```

This means if the CIDRs change, the NACLs update automatically.

### Sensitive variable handling

The authorized SSH IP was removed from `variables.tf` defaults entirely. It has no default — Terraform will error if it is not provided. It is passed at runtime via a `terraform.tfvars` file locally (blocked by `.gitignore`) and via GitHub Secrets in the pipeline.

---

## Phase 1 — Remote Backend (S3 + DynamoDB)

### Why remote state

Local state files (`terraform.tfstate`) are fragile — they can be lost, corrupted, or cause conflicts if two people apply simultaneously. Remote state in S3 with DynamoDB locking is the production standard.

### Commands executed

**Create S3 bucket:**
```bash
aws s3api create-bucket \
  --bucket tf-state-vpc-security-474945406391 \
  --region us-east-1
```

The bucket name includes the AWS account ID to ensure global uniqueness.

**Enable versioning:**
```bash
aws s3api put-bucket-versioning \
  --bucket tf-state-vpc-security-474945406391 \
  --versioning-configuration Status=Enabled
```

**Enable encryption:**
```bash
aws s3api put-bucket-encryption \
  --bucket tf-state-vpc-security-474945406391 \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

**Create DynamoDB table for locking:**
```bash
aws dynamodb create-table \
  --table-name terraform-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

**backend.tf configuration:**
```hcl
terraform {
  backend "s3" {
    bucket         = "tf-state-vpc-security-474945406391"
    key            = "vpc-security-lab/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-lock"
    encrypt        = true
  }
}
```

**Initialize with remote backend:**
```bash
cd environments/dev
terraform init
terraform apply
```

The first apply from the new module structure validated that the refactor was correct and that Terraform could manage state remotely.

---

## Phase 2 — OIDC Authentication

### Why OIDC instead of access keys

The conventional approach to authenticating GitHub Actions with AWS is to create an IAM user, generate access keys, and store them as GitHub Secrets. This has several problems: the keys are long-lived secrets that can be leaked, they require rotation, and they exist as persistent credentials that could be misused.

OIDC (OpenID Connect) eliminates this entirely. GitHub generates a short-lived JWT token on each pipeline run. AWS verifies the token against GitHub's OIDC provider and issues temporary credentials scoped to a specific IAM Role. No secret is stored anywhere.

### Commands executed

**Create OIDC provider in AWS:**
```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

**Create IAM Role with trust policy scoped to this repository:**

The trust policy uses `StringLike` with a wildcard on the `sub` claim, allowing any branch or workflow in the repository to assume the role:

```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::474945406391:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
      },
      "StringLike": {
        "token.actions.githubusercontent.com:sub": "repo:sxaAspri/aws-vpc-security-lab-cicd:*"
      }
    }
  }]
}
```

```bash
aws iam create-role \
  --role-name github-actions-vpc-security \
  --assume-role-policy-document file://trust-policy.json
```

**Attach least-privilege permissions:**

The role was given only the permissions needed to deploy the specific resources in this lab — EC2, VPC, IAM (for Flow Logs role), CloudWatch, S3 (for state), and DynamoDB (for locking). No `AdministratorAccess` or broad wildcards beyond what was necessary.

```bash
aws iam put-role-policy \
  --role-name github-actions-vpc-security \
  --policy-name vpc-security-deploy \
  --policy-document file://permissions-policy.json
```

---

## Phase 3 — GitHub Actions Pipeline

### Pipeline structure

The pipeline was designed with four sequential jobs. Each job depends on the previous — if any fails, the chain stops and infrastructure is never touched.

```yaml
validate → security-scan → plan → apply
```

**Validate:** Runs `terraform fmt -check` and `terraform validate`. Catches formatting issues and syntax errors before any AWS interaction.

**Security Scan:** Runs Checkov against `modules/vpc-security`. This is the security gate — if Checkov finds critical misconfigurations, the pipeline stops before plan or apply ever run.

**Plan:** Runs `terraform plan` to show exactly what will change in AWS. Provides visibility before any change is made.

**Apply:** Runs `terraform apply` only on push to `main`. Uses OIDC to authenticate — no credentials are stored in GitHub.

### OIDC configuration in the pipeline

```yaml
- name: Configure AWS credentials via OIDC
  uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::474945406391:role/github-actions-vpc-security
    aws-region: us-east-1
```

### Sensitive variable injection

The authorized SSH CIDR is stored as a GitHub Secret (`ALLOWED_SSH_CIDR`) and injected at runtime:

```yaml
run: terraform plan -var="allowed_ssh_cidr=${{ secrets.ALLOWED_SSH_CIDR }}"
```

This means the IP never appears in any file in the repository.

---

## Phase 4 — Security Gate (Checkov)

### What Checkov does

Checkov performs static analysis on Terraform code. It does not connect to AWS — it reads the `.tf` files and checks them against a library of security rules. This means it catches problems before any infrastructure is created.

### Issues found and resolved

**Round 1 — EC2 configuration issues:**

| Check | Issue | Resolution |
|---|---|---|
| CKV_AWS_79 | IMDSv2 not enforced | Added `metadata_options { http_tokens = "required" }` to all EC2 instances |
| CKV_AWS_126 | Detailed monitoring disabled | Added `monitoring = true` to all EC2 instances |
| CKV_AWS_135 | EC2 not EBS optimized | Skipped — `t2.micro` does not support EBS optimization |
| CKV_AWS_88 | Bastion has public IP | Skipped — intentional by design, bastion requires public access |

**Round 2 — Network and IAM issues (all skipped as lab-appropriate):**

| Check | Reason for skip |
|---|---|
| CKV_AWS_382 | Security groups allow egress to `0.0.0.0/0` — standard outbound pattern |
| CKV_AWS_231 | NACLs — RDP port check not relevant to this lab |
| CKV_AWS_290 | IAM Flow Logs policy — write access required for functionality |
| CKV_AWS_355 | IAM policy uses `*` as resource — required for Flow Logs role |
| CKV_AWS_338 | Log retention < 1 year — cost optimization for lab |
| CKV_AWS_158 | CloudWatch not KMS encrypted — cost optimization for lab |

**Round 3 — Final issues (skipped as lab-appropriate):**

| Check | Reason for skip |
|---|---|
| CKV2_AWS_41 | EC2 instances have no IAM role — not required for this network-focused lab |
| CKV_AWS_130 | Public subnets auto-assign IPs — intentional, bastion needs public IP |

### Final pipeline result

After resolving and documenting all checks, the pipeline ran clean:

```
Validate      16s
Security Scan 19s
Plan          15s
Apply         19s

Status: Success — 1m 23s
```

---

## Teardown

Resources are destroyed at the end of each session to avoid ongoing NAT Gateway charges:

```bash
cd environments/dev
terraform destroy
```

The S3 bucket and DynamoDB table are retained between sessions — they hold the state and lock configuration and cost negligible amounts to keep.

---

## What This Lab Demonstrates

By the end of this lab, the following capabilities are operational and evidenced:

- Infrastructure as Code deployed automatically on every push to `main`
- AWS authentication without any stored credentials using OIDC
- Security validation enforced as a pipeline gate before any AWS interaction
- Remote state management with concurrent access protection
- Reusable Terraform module structure ready for multi-environment use
- Least-privilege IAM throughout — pipeline role, Flow Logs role, and module variables
