# Troubleshooting Log — AWS VPC Security Lab

## Why Document This?

Most portfolio projects only show the happy path — the final result after everything worked. This document takes a different approach. It captures every problem encountered during the build, the symptoms observed, the root cause identified, and the solution applied.

Debugging is a core skill in cloud security work. Being able to read an error, form a hypothesis, and iterate toward a fix is what separates someone who can follow a tutorial from someone who can actually build and operate infrastructure. This log exists as evidence of that process.

---
## Issue 1 — SSM Session Manager Unavailable Without IAM Instance Profile

### Problem
When trying to access the data EC2 directly through the AWS Console to debug the `user_data` issue, SSM Session Manager was not available.

### Symptom
```
SSM agent status: Offline
Session Manager connection status: Not connected
DHMC is not enabled and IAM instance profile is not attached.
```

### Root Cause
SSM Session Manager requires the EC2 instance to have an IAM instance profile with the `AmazonSSMManagedInstanceCore` policy attached. The data EC2 was not provisioned with any IAM role, so the SSM agent could not register with the Systems Manager service. The EC2 Serial Console was also unavailable as it was not enabled at the account level.

### Solution
For this lab, the debugging path was changed to fix the `user_data` script directly rather than accessing the instance. The correct production solution for isolated instances is to attach an IAM instance profile with SSM permissions and configure SSM VPC endpoints so the agent can reach the service without internet access.

### Lesson
SSM Session Manager is the production-recommended alternative to SSH bastion hosts — it eliminates the need for open port 22 entirely. However, it requires both an IAM role on the instance and either internet access or SSM VPC endpoints. Planning for instance access patterns should happen at architecture design time, not as an afterthought during debugging.

---


## Issue 2 — `user_data` Script Failing Silently on Data EC2

### Problem
The data EC2 was provisioned successfully, but the port 5432 listener was never running. Connection attempts from the app layer returned `Connection refused` instead of a successful connection.

### Symptom
```
[ec2-user@ip-10-0-11-220 ~]$ nc -zv 10.0.21.104 5432
Ncat: Connection refused.
```

### Root Cause
The original `user_data` script attempted to install `nmap-ncat` via `yum install` at boot time. However, the data EC2 sits in a subnet with **no internet route by design** — the data layer route table has no NAT Gateway entry. This means `yum` could not reach the package repositories and the installation silently failed, leaving no listener running on port 5432.

This was a blind spot: the network isolation that was correctly implemented for security also prevented the instance from bootstrapping software at launch.

### Solution
Replaced the `user_data` script with a pure Python socket listener that requires no external packages. Python 3 ships pre-installed on Amazon Linux 2023:

```bash
#!/bin/bash
python3 -c "
import socket
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(('0.0.0.0', 5432))
s.listen(5)
while True:
    conn, addr = s.accept()
    conn.send(b'DB simulation running\n')
    conn.close()
" &
```

### Lesson
Network isolation affects not just runtime traffic, but also instance bootstrapping. When designing isolated subnets, account for how instances will install software or receive configuration at launch. Options include: pre-baked AMIs, AWS Systems Manager with VPC endpoints, S3 VPC endpoints for package caching, or — as done here — using pre-installed runtimes instead of pulling packages.

---

## Issue 3 — Wrong Resource Type for CloudWatch Metric Filter

### Problem
`terraform plan` failed with an invalid resource type error in `flow-logs.tf`.

### Symptom
```
Error: Invalid resource type
  on flow-logs.tf line 69:
  69: resource "aws_cloudwatch_metric_filter" "rejected_data" {
The provider hashicorp/aws does not support resource type "aws_cloudwatch_metric_filter".
```

### Root Cause
The correct Terraform resource type for a CloudWatch metric filter tied to a log group is `aws_cloudwatch_log_metric_filter`, not `aws_cloudwatch_metric_filter`. The latter does not exist in the AWS provider.

### Solution
Renamed the resource type in `flow-logs.tf`:

```hcl
# Before
resource "aws_cloudwatch_metric_filter" "rejected_data" {

# After
resource "aws_cloudwatch_log_metric_filter" "rejected_data" {
```

### Lesson
The AWS Terraform provider has many similarly named resources. When in doubt, check the [Terraform AWS Provider documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs) directly rather than guessing the resource name.

---

## Issue 4 — `common_tags` Declared Outside `locals` Block

### Problem
During `terraform init`, Terraform threw an error pointing to `variables.tf`.

### Symptom
```
Error: Unsupported argument
  on variables.tf line 24:
  24: common_tags = {
An argument named "common_tags" is not expected here.
```

### Root Cause
The `common_tags` map was written directly inside the `variables.tf` file as a top-level expression, without wrapping it in a `locals {}` block. In Terraform, local values must be declared inside a `locals` block — they cannot be defined as free-standing assignments.

### Solution
Wrapped `common_tags` inside a proper `locals` block:

```hcl
locals {
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}
```

### Lesson
In Terraform there are three distinct constructs for storing values: `variable` (input), `local` (computed/derived), and `output` (exposed). Each has its own block syntax. Mixing them up is a common early mistake — knowing the difference is fundamental.

---


## Issue 5 — Duplicate Resource Declaration in `flow-logs.tf`

### Problem
After fixing Issue 3, `terraform plan` reported a duplicate resource error.

### Symptom
```
Error: Duplicate resource "aws_cloudwatch_log_metric_filter" configuration
  on flow-logs.tf line 81:
  81: resource "aws_cloudwatch_log_metric_filter" "rejected_data" {
A aws_cloudwatch_log_metric_filter resource named "rejected_data" was already declared at flow-logs.tf:69,1-60.
```

### Root Cause
When fixing Issue 3, the resource type was corrected on line 69, but the second block (which was actually the `aws_cloudwatch_metric_alarm` resource) still had the wrong type from a previous incorrect edit. This created two resources with the same type and name.

### Solution
Corrected the second block to its proper resource type:

```hcl
resource "aws_cloudwatch_metric_alarm" "rejected_data" {
  alarm_name = "${var.project_name}-rejected-to-data-alarm"
  ...
}
```

### Lesson
When editing resource types in a file, always review the full file context after making changes. A fix applied to the wrong block can introduce a new error while appearing to resolve the original one.

---


## Issue 6 — `nc` Command Not Found; Wrong Binary Name

### Problem
After SSHing into the app EC2, running `nc` returned command not found.

### Symptom
```
[ec2-user@ip-10-0-11-220 ~]$ nc -zv 10.0.21.104 5432
-bash: nc: command not found
```

### Root Cause
On Amazon Linux 2023, the `nc` (netcat) binary is not installed by default. The package `nmap-ncat` provides the `ncat` binary. The two names are often used interchangeably in documentation but are different binaries on different distributions.

### Solution
Installed the correct package on the app EC2:

```bash
sudo yum install -y nmap-ncat
```

### Lesson
Package names, binary names, and command aliases vary between Linux distributions and versions. Always verify binary availability on the specific OS in use. Amazon Linux 2023 differs meaningfully from Amazon Linux 2 in default package availability.

---

## Issue 7 — SSH Key Permissions on Windows

### Problem
Attempting to SSH into the bastion using the `.pem` key file requires correct file permissions on Windows.

### Symptom
```
WARNING: UNPROTECTED PRIVATE KEY FILE!
Permissions for 'vpc-security-lab-key.pem' are too open.
```

### Root Cause
On Linux/macOS, SSH requires private key files to have permissions set to `400` (owner read-only). Windows uses a different permission model, but modern OpenSSH on Windows enforces similar restrictions and will reject keys with overly permissive access.

### Solution
Used `icacls` to restrict access to the key file to the current user only:

```bash
icacls "vpc-security-lab-key.pem" /inheritance:r /grant:r "andre:(R)"
```

### Lesson
SSH key security is enforced by the SSH client, not just recommended. On Windows, use `icacls` to manage file permissions for `.pem` files. Never store private keys in shared or world-readable locations.

---

