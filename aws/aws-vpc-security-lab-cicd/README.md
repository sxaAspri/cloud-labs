# AWS VPC Security Lab — Secure CI/CD Pipeline for IaC

![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat-square)
![Type](https://img.shields.io/badge/Type-Cloud%20Security%20Lab-blue?style=flat-square)
![Cloud](https://img.shields.io/badge/Cloud-AWS-orange?style=flat-square)
![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat-square)
![CI/CD](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-2088FF?style=flat-square)
![Auth](https://img.shields.io/badge/Auth-OIDC-success?style=flat-square)
![Scanner](https://img.shields.io/badge/Scanner-Checkov-red?style=flat-square)
![Environment](https://img.shields.io/badge/Environment-us--east--1-lightgrey?style=flat-square)

> Extension of the [AWS VPC Security Lab](../aws-vpc-security-lab/) that adds a production-grade CI/CD pipeline for automated, secure infrastructure deployment using Terraform, GitHub Actions, and OIDC authentication — with a built-in security gate powered by Checkov.

🔗 **Live repository with active pipeline:** [aws-vpc-security-lab-cicd](https://github.com/sxaAspri/aws-vpc-security-lab-cicd)

---

## Overview

This lab takes the three-tier VPC architecture built in the previous lab and wraps it in a complete DevSecOps pipeline. The goal is to demonstrate that infrastructure can be deployed automatically, securely, and consistently — without static credentials, without manual steps, and with security validation enforced before any resource is created in AWS.

The pipeline enforces a strict gate sequence: code must pass format and syntax validation, then a security scan, before Terraform is ever allowed to plan or apply.

---

## Architecture

```
Developer
    │
    │  git push to main
    ▼
GitHub Actions Pipeline
    │
    ├── Job 1: Validate
    │     terraform fmt -check
    │     terraform validate
    │
    ├── Job 2: Security Scan (Checkov)
    │     Static analysis of all .tf files
    │     Blocks pipeline on critical findings
    │
    ├── Job 3: Plan
    │     terraform plan
    │     Shows changes before applying
    │
    └── Job 4: Apply
          terraform apply (main branch only)
          Authenticates via OIDC — no static credentials
                │
                ▼
            AWS (us-east-1)
                │
                ├── VPC (10.0.0.0/16)
                │     ├── Public layer  → Bastion Host
                │     ├── App layer     → App EC2
                │     └── Data layer    → Data EC2 (simulated DB)
                │
                ├── S3 Backend       → Remote Terraform state
                ├── DynamoDB         → State locking
                └── CloudWatch       → VPC Flow Logs + Alerts
```

---

## What This Lab Adds Over the Base VPC Lab

| Capability | Base VPC Lab | This Lab |
|---|---|---|
| Infrastructure deployment | Manual (`terraform apply`) | Automated via GitHub Actions |
| AWS authentication | Static credentials (local) | OIDC — no credentials stored |
| Terraform state | Local `.tfstate` file | Remote S3 + DynamoDB locking |
| Security validation | Manual review | Automated Checkov gate |
| Code validation | Manual | `terraform fmt` + `validate` on every push |
| Multi-environment support | Single flat config | Module + environments structure |
| Deployment control | Anyone with CLI access | Pipeline enforces branch protection |

---

## Pipeline Flow

```
push to main
    │
    ▼
 Validate (16s)    — fmt check + syntax validation
    │
    ▼
 Security Scan (19s) — Checkov static analysis
    │                    blocks on critical findings
    ▼
 Plan (15s)        — shows what will change in AWS
    │
    ▼
 Apply (19s)       — deploys infrastructure via OIDC
```

Total pipeline duration: ~1m 23s

---

## Services Used

| Service | Purpose |
|---|---|
| GitHub Actions | CI/CD pipeline orchestration |
| OIDC (IAM) | Credential-free authentication from GitHub to AWS |
| Checkov | Static security analysis of Terraform code |
| S3 | Remote Terraform state storage |
| DynamoDB | Terraform state locking |
| VPC | Isolated three-tier network |
| EC2 | Bastion, app, and data simulation instances |
| VPC Flow Logs | Network traffic capture |
| CloudWatch | Log storage and alerting |
| IAM | Least-privilege roles for pipeline and Flow Logs |

---

## Security Controls

### OIDC Authentication
GitHub Actions assumes an IAM Role using a short-lived OIDC token on every pipeline run. No AWS access keys are stored anywhere — not in GitHub secrets, not in the repository, not in environment variables.

### Checkov Security Gate
Checkov runs as a blocking step before `terraform plan`. If it finds critical misconfigurations, the pipeline stops and infrastructure is never touched. Checks enforced include:

- IMDSv2 required on all EC2 instances (`CKV_AWS_79`)
- Detailed monitoring enabled on EC2 (`CKV_AWS_126`)
- No public SSH access beyond authorized IP
- VPC Flow Logs enabled

### Terraform Module Structure
Infrastructure is organized as a reusable module consumed by environment-specific configurations. No hardcoded values — sensitive inputs like the authorized SSH CIDR are injected via GitHub Secrets at runtime.

### Remote State
Terraform state is stored in S3 with versioning and AES-256 encryption enabled. DynamoDB provides state locking to prevent concurrent apply conflicts.

---

## Repository Structure

```
aws-vpc-security-lab-cicd/
├── modules/
│   └── vpc-security/
│       ├── main.tf
│       ├── variables.tf
│       ├── subnets.tf
│       ├── routing.tf
│       ├── security-groups.tf
│       ├── nacls.tf
│       ├── flow-logs.tf
│       ├── ec2.tf
│       └── outputs.tf
├── environments/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── provider.tf
│       └── backend.tf
├── .github/
│   └── workflows/
│       └── pipeline.yml
└── .gitignore
```

---

## Prerequisites

- AWS account with CLI configured
- Terraform >= 1.3.0
- GitHub repository with Actions enabled
- SSH key pair created in AWS

---

## Key Design Decisions

**Why OIDC instead of access keys?** Static credentials are a persistent secret that can be leaked, rotated incorrectly, or forgotten in a repository. OIDC tokens are short-lived, scoped to a specific repository and branch, and require no secret management.

**Why Checkov before Plan?** Running security analysis before `terraform plan` means the pipeline never authenticates to AWS with insecure code. The gate is meaningful — not just advisory.

**Why a module structure?** Separating the module from the environment allows the same infrastructure definition to be reused across dev and prod with different inputs, without duplicating code.

**Why S3 + DynamoDB for state?** Local state files are fragile — they can be lost, corrupted, or cause conflicts when multiple people work on the same infrastructure. Remote state with locking is the production standard.

---

## Evidence

| Artifact | Description |
|---|---|
| GitHub Actions runs | Full pipeline execution with all 4 jobs green |
| Checkov output | Security scan results with passing checks |
| S3 bucket | Remote state file stored with versioning |
| DynamoDB table | Lock table for concurrent apply protection |
| IAM Role | OIDC trust policy scoped to this repository |
| VPC Flow Logs | Network traffic capture in CloudWatch |

Screenshots available in `docs/screenshots/`.

---

## Estimated Cost

A full lab session (4–6 hours) costs under $0.30 USD, driven primarily by NAT Gateway hourly charges. All resources are destroyed with `terraform destroy` at the end of each session. The S3 bucket and DynamoDB table are retained between sessions at negligible cost.

---

## Related Labs

- [AWS VPC Security Lab](../aws-vpc-security-lab/) — Base three-tier network architecture this pipeline deploys
- [AWS Security Detection Lab](../lab-aws-security-detection/) — Threat detection pipeline with GuardDuty and EventBridge
- [Self-Healing AWS Infrastructure](../lab-aws-self-healing-infrastructure/) — Automated incident response with Lambda

---

## References

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [GitHub Actions OIDC with AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
- [Checkov Documentation](https://www.checkov.io/1.Welcome/What%20is%20Checkov.html)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
