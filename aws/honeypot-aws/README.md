# Honeypot AWS — Threat Intelligence Lab

![Status](https://img.shields.io/badge/Status-Complete-brightgreen)
![Type](https://img.shields.io/badge/Type-Security%20Lab-red)
![Environment](https://img.shields.io/badge/Environment-AWS-orange)
![Framework](https://img.shields.io/badge/IaC-Terraform-purple)
![Tool](https://img.shields.io/badge/Honeypot-Cowrie-blue)

A trap server deployed on AWS that captures real SSH attacks, automatically analyzes them, and blocks attacker IPs — all without manual intervention.

During testing, the honeypot captured real attacks from bots in less than 5 minutes of being active, including attempts from China (CHINANET Liaoning).

## Architecture

```
Real Attacker / Bot
        ↓
   Honeypot EC2
   (Cowrie SSH)
        ↓
CloudWatch Logs
(/honeypot/cowrie)
        ↓
Lambda analyzer
   ↓         ↓         ↓
  SNS       S3       Security Group
(email)  (report)   (IP block)
```

## Services Used

| Service | Role |
|---|---|
| EC2 | Trap server running Cowrie |
| Cowrie | SSH honeypot that simulates a vulnerable system |
| CloudWatch Logs | Captures Cowrie logs in real time |
| Lambda | Analyzes attacks and orchestrates the response |
| S3 | Stores JSON reports for each attack |
| SNS | Sends email alerts |
| Security Group | Automatically blocks attacker IPs |
| IAM | Least-privilege permissions for each service |
| Terraform | Infrastructure as code |

## What Cowrie Captures

For each attack session:
- Attacker IP address
- Operating system and SSH client used
- Attempted credentials (username/password)
- Commands executed inside the fake system
- Session duration
- Files the attacker tried to download

## Attack Classification

| Type | Criteria |
|---|---|
| SSH Brute Force | 5+ failed login attempts |
| SSH Intrusion + Command Execution | Successful login + commands executed |
| SSH Intrusion | Successful login without commands |
| SSH Probe | Connection without successful login |

## Requirements

- Active AWS account
- AWS CLI configured (`aws configure`)
- Terraform >= 1.0 installed

## Deployment

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/honeypot-aws.git
cd honeypot-aws/terraform

# 2. In lambda.tf replace YOUR_EMAIL_HERE with your real email

# 3. Initialize Terraform
terraform init

# 4. Review the plan
terraform plan

# 5. Deploy
terraform apply
```

## Post-Deployment Configuration

After `terraform apply`, connect to the EC2 via EC2 Instance Connect and run:

```bash
# Install Cowrie dependencies
sudo su - cowrie
cd /home/cowrie/cowrie
python3.11 -m venv cowrie-env
source cowrie-env/bin/activate
pip install -r requirements.txt
pip install -e .

# Configure port 22
sed -i '645s/.*/listen_endpoints = tcp:22:interface=0.0.0.0/' etc/cowrie.cfg

# Grant Python permission to use port 22
exit
sudo setcap cap_net_bind_service=+ep /usr/bin/python3.11

# Move real SSH to port 2222
sudo sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Install and start CloudWatch Agent
sudo dnf install -y amazon-cloudwatch-agent
sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s

# Start Cowrie
sudo su - cowrie
cd /home/cowrie/cowrie
source cowrie-env/bin/activate
bin/regen-dropin.cache
cowrie-env/bin/cowrie start
```

## Verify It's Working

```bash
# View logs in real time
cat /home/cowrie/cowrie/var/log/cowrie/cowrie.log

# View JSON logs
tail -f /home/cowrie/cowrie/var/log/cowrie/cowrie.json
```

## Cleanup

```bash
cd terraform
terraform destroy
```

## Project Structure

```
honeypot-aws/
├── README.md
├── terraform/
│   ├── main.tf         # AWS provider
│   ├── ec2.tf          # EC2 + Security Group
│   ├── iam.tf          # Roles and permissions
│   ├── storage.tf      # S3 reports bucket
│   └── lambda.tf       # Lambda + SNS + CloudWatch subscription
├── lambda/
│   └── analyzer.py     # Analysis and response function
├── docs/
│   └── architecture.md # Architecture notes
└── screenshots/        # Evidence of functionality
```

## Demo — Real Results

During testing, real attacks were captured in less than 5 minutes:

- **Chinese bot** from `43.226.46.130` — CHINANET Liaoning, China
- IP automatically blocked in the Security Group
- Report generated and sent by email within seconds

See the `screenshots/` folder for visual evidence.

## Author

ASPRIIII
