# AWS VPC Security Lab — Network Segmentation & Traffic Control

![Status](https://img.shields.io/badge/Status-Complete-brightgreen?style=for-the-badge)
![Type](https://img.shields.io/badge/Type-Security%20Lab-red?style=for-the-badge)
![Environment](https://img.shields.io/badge/Environment-Lab-blue?style=for-the-badge)
![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=for-the-badge&logo=terraform)
![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?style=for-the-badge&logo=amazonaws)
![Region](https://img.shields.io/badge/Region-us--east--1-orange?style=for-the-badge)

## Overview

This lab implements a production-grade three-tier network segmentation architecture on AWS, applying the principle of least privilege at the network level. The goal is to demonstrate that a properly segmented VPC — with Security Groups, Network ACLs, and controlled routing — can enforce strict traffic isolation between layers, even within the same private network.

The lab was fully provisioned with Terraform and validated through real connectivity tests, with all accepted and rejected traffic captured in VPC Flow Logs.

---

## Architecture

```
Internet
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16)                    │
│                                                         │
│  ┌──────────────────────────────────────────────────┐   │
│  │           PUBLIC LAYER (10.0.1.0/24)             │   │
│  │                                                  │   │
│  │   [Bastion Host]  ← SSH from authorized IP only  │   │
│  │        │                                         │   │
│  │        │ SSH only                                │   │
│  │        ▼                                         │   │
│  ├──────────────────────────────────────────────────┤   │
│  │           APP LAYER (10.0.11.0/24)               │   │
│  │                                                  │   │
│  │   [App EC2]  ← reachable only from bastion       │   │
│  │        │                                         │   │
│  │        │ Port 5432 only                          │   │
│  │        ▼                                         │   │
│  ├──────────────────────────────────────────────────┤   │
│  │           DATA LAYER (10.0.21.0/24)              │   │
│  │                                                  │   │
│  │   [Data EC2]  ← reachable only from app layer    │   │
│  │   No internet route — fully isolated             │   │
│  └──────────────────────────────────────────────────┘   │
│                                                         │
│  IGW ──► Public RT     NAT ──► App RT     Data RT (none)│
└─────────────────────────────────────────────────────────┘
```

### Network Design

| Layer | Subnet A | Subnet B | Internet Access |
|---|---|---|---|
| Public | 10.0.1.0/24 (us-east-1a) | 10.0.2.0/24 (us-east-1b) | Direct via IGW |
| App | 10.0.11.0/24 (us-east-1a) | 10.0.12.0/24 (us-east-1b) | Outbound only via NAT |
| Data | 10.0.21.0/24 (us-east-1a) | 10.0.22.0/24 (us-east-1b) | None — fully isolated |

---

## AWS Services Used

| Service | Purpose |
|---|---|
| VPC | Isolated virtual network |
| Subnets | Layer segmentation across 2 AZs |
| Internet Gateway | Public layer internet access |
| NAT Gateway | Outbound-only internet for app layer |
| Route Tables | Traffic routing per layer |
| Security Groups | Stateful firewall per instance |
| Network ACLs | Stateless firewall per subnet |
| VPC Flow Logs | Full traffic capture (ACCEPT + REJECT) |
| CloudWatch Logs | Centralized log storage |
| CloudWatch Metric Filter | REJECT detection on port 5432 |
| CloudWatch Alarm | Alert on rejected traffic to data layer |
| EC2 | Bastion, app, and data simulation instances |
| IAM | Role for Flow Logs to write to CloudWatch |

---

## Security Controls

### Security Groups (Stateful)

| Security Group | Inbound Rule | Source |
|---|---|---|
| sg-bastion | TCP 22 | Authorized IP only (`/32`) |
| sg-app | TCP 22 | sg-bastion only |
| sg-data | TCP 5432 | sg-app only |

### Network ACLs (Stateless)

| NACL | Layer | Key Inbound Rules | Key Outbound Rules |
|---|---|---|---|
| nacl-public | Public subnets | Allow SSH from authorized IP, allow ephemeral return | Allow all |
| nacl-app | App subnets | Allow SSH from VPC CIDR, allow ephemeral return | Allow all |
| nacl-data | Data subnets | Allow 5432 from app subnets only, deny all else | Allow ephemeral to app subnets only, deny all else |

---

## Project Structure

```
aws-vpc-security-lab/
├── terraform/
│   ├── provider.tf
│   ├── variables.tf
│   ├── vpc.tf
│   ├── subnets.tf
│   ├── routing.tf
│   ├── security-groups.tf
│   ├── nacls.tf
│   ├── flow-logs.tf
│   ├── ec2.tf
│   └── outputs.tf
├── docs/
│   ├── screenshots/
│   └── troubleshooting.md
└── README.md
```

---

## Prerequisites

- AWS CLI configured with a least-privilege IAM user
- Terraform >= 1.3.0
- An SSH key pair (created during setup)
- Your public IP address for SSH access restriction

---

## Deployment

**1. Clone the repository and navigate to the terraform directory:**

```bash
git clone https://github.com/your-username/aws-vpc-security-lab
cd aws-vpc-security-lab/terraform
```

**2. Verify your AWS identity:**

```bash
aws sts get-caller-identity
```

**3. Initialize Terraform:**

```bash
terraform init
```

**4. Review the plan:**

```bash
terraform plan -out=tfplan
```

**5. Apply:**

```bash
terraform apply "tfplan"
```

**6. Note the outputs** — bastion public IP, app and data private IPs, and the Flow Logs group name.

---

## Connectivity Validation

After deployment, the following tests were performed to validate the architecture:

### Test 1 — SSH into bastion from authorized IP
```bash
ssh -i "vpc-security-lab-key.pem" ec2-user@<bastion-public-ip>
```
**Result:** Connected ✅

### Test 2 — SSH from bastion into app layer
```bash
ssh -i ~/.ssh/vpc-security-lab-key.pem ec2-user@<app-private-ip>
```
**Result:** Connected ✅

### Test 3 — App layer to data layer on port 5432
```bash
nc -zv <data-private-ip> 5432
```
**Result:** `Ncat: Connected` ✅

### Test 4 — Bastion to data layer on port 5432
```bash
nc -zv <data-private-ip> 5432
```
**Result:** `Ncat: TIMEOUT` ❌ — blocked by Security Group + NACL

### Test 5 — Internet to data layer on port 5432
```powershell
Test-NetConnection -ComputerName <data-private-ip> -Port 5432
```
**Result:** `TcpTestSucceeded: False` ❌ — no route, no access

---

## Findings Summary

| Test | Origin | Destination | Port | Result | Control Enforcing |
|---|---|---|---|---|---|
| 1 | Authorized IP | Bastion | 22 | ALLOW | SG + NACL |
| 2 | Bastion | App EC2 | 22 | ALLOW | SG + NACL |
| 3 | App EC2 | Data EC2 | 5432 | ALLOW | SG + NACL |
| 4 | Bastion | Data EC2 | 5432 | REJECT | SG + NACL |
| 5 | Internet | Data EC2 | 5432 | REJECT | Routing + SG + NACL |

All accepted and rejected traffic was captured in VPC Flow Logs and is visible in CloudWatch Logs. A CloudWatch alarm was configured to fire on any rejected connection attempt to port 5432, providing real-time detection capability.

---

## Flow Log Evidence

Flow logs captured both ACCEPT and REJECT records. Example entries from CloudWatch:

- `10.0.11.220 → 10.0.21.155 : 5432 — ACCEPT` (app to data, permitted)
- `10.0.1.190 → 10.0.21.155 : 5432 — REJECT` (bastion to data, blocked)

See `docs/screenshots/` for full evidence.

---

## Teardown

```bash
terraform destroy
```

All resources are tagged with `ManagedBy = Terraform` for easy identification. Estimated cost for a full lab session (4–6 hours): under $1 USD, driven primarily by NAT Gateway hourly charges.

---

## Troubleshooting

For a detailed account of issues encountered during this lab and how they were resolved, see [docs/troubleshooting.md](docs/troubleshooting.md).

---

## References

- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/latest/userguide/)
- [Terraform AWS Provider — VPC](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/vpc)
- [VPC Flow Logs](https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html)
- [Security Groups vs NACLs](https://docs.aws.amazon.com/vpc/latest/userguide/VPC_Security.html)
