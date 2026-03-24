# 🛡️ Self-Healing AWS Security Lab

![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat-square)
![Type](https://img.shields.io/badge/Type-Cloud%20Security%20Lab-blue?style=flat-square)
![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)
![IaC](https://img.shields.io/badge/IaC-Terraform-7B42BC?style=flat-square&logo=terraform&logoColor=white)
![Services](https://img.shields.io/badge/Services-GuardDuty%20%7C%20Lambda%20%7C%20EC2-orange?style=flat-square)
![Focus](https://img.shields.io/badge/Focus-Automated%20Incident%20Response-red?style=flat-square)

A secure and self-healing infrastructure on AWS. When Amazon GuardDuty detects a threat, the system automatically terminates the compromised EC2 instance and replaces it with a clean one launched from a preconfigured AMI.

## 🏗️ Architecture

```
Attacker / Simulation
        ↓
   EC2 Instance
        ↓
 CloudTrail (logs)
        ↓
  GuardDuty (ML)
        ↓
EventBridge (severity ≥ 7)
        ↓
Lambda (orchestration)
   ↓           ↓
  SNS        EC2 Auto-recovery
(email)    (terminate + relaunch AMI)
```

## ☁️ Services Used

| Service     | Role                             |
| ----------- | -------------------------------- |
| EC2         | Protected server                 |
| AMI         | Clean image for recovery         |
| CloudTrail  | Activity logging                 |
| GuardDuty   | Threat detection using ML        |
| EventBridge | Event filtering and routing      |
| Lambda      | Automated response orchestration |
| SNS         | Email notifications              |
| Terraform   | Infrastructure as Code           |

## 📋 Requirements

* Active AWS account
* AWS CLI configured (`aws configure`)
* Terraform >= 1.0 installed

## 🚀 Deployment

```bash
# 1. Clone the repository
git clone https://github.com/sxaAspri/self-healing-aws.git
cd self-healing-aws/terraform

# 2. In response.tf replace TU_EMAIL_AQUI with your real email

# 3. Initialize Terraform
terraform init

# 4. Review execution plan
terraform plan

# 5. Deploy infrastructure
terraform apply
```

## 🧪 Full Cycle Test

From the root of the project, simulate an attack:

```bash
aws lambda invoke \
  --function-name self-healing-response \
  --payload file://test-event.json \
  --cli-binary-format raw-in-base64-out \
  response.json
```

### ✅ Expected Results

1. Security alert email notification
2. Compromised EC2 instance terminated
3. New EC2 instance launched from clean AMI
4. Recovery confirmation email received

## 🧹 Cleanup

**Important:** Run this command after testing to avoid unnecessary costs.

```bash
cd terraform
terraform destroy
```

## 📁 Project Structure

```
self-healing-aws/
├── README.md
├── test-event.json      # Simulated event for testing
├── terraform/
│   ├── main.tf          # AWS provider configuration
│   ├── ec2.tf           # EC2 + Security Group
│   ├── ami.tf           # Recovery AMI
│   ├── detection.tf     # CloudTrail + GuardDuty + S3
│   ├── response.tf      # SNS + email subscription
│   └── lambda.tf        # Lambda + EventBridge + IAM
├── lambda/
│   └── handler.py       # Automated response function
└── docs/
    └── architecture.md  # Architecture notes
```

## 📚 Key Learnings

* Infrastructure as Code using Terraform
* Threat detection with Amazon GuardDuty
* Event-driven architecture with EventBridge
* Automated incident response using AWS Lambda
* Self-healing EC2 infrastructure

## 👨‍💻 Author

Andres — [@sxaAspri](https://github.com/sxaAspri)
