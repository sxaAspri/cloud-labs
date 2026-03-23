# 🏗️ Architecture Notes

## 🔄 End-to-End Flow

1. **EC2** runs with a Security Group exposing SSH (port 22)
2. **CloudTrail** logs all account activity and stores it in S3
3. **GuardDuty** analyzes logs and detects anomalous behavior
4. **EventBridge** filters findings with severity >= 7 and forwards them to Lambda
5. **Lambda** executes the automated response:

   * Publishes alert to SNS → email notification
   * Terminates the compromised instance
   * Launches a new instance from a clean AMI
   * Publishes recovery confirmation to SNS → email notification

## 🧠 Design Decisions

* **t2.micro** — Free Tier eligible and sufficient for lab purposes
* **Severity >= 7** — Filters only high-risk threats, reducing noise
* **Preconfigured AMI** — Ensures recovered instances are clean and secure
* **S3 `force_destroy`** — Allows `terraform destroy` to complete without errors

## 🚀 Possible Improvements

* Implement a dedicated VPC with public and private subnets
* Use AWS Systems Manager instead of direct SSH access
* Add Slack notifications in addition to email alerts
* Create a CloudWatch dashboard to visualize findings
* Integrate AWS Config for continuous compliance monitoring
