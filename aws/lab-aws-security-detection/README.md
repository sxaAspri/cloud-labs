# 🔐 AWS Threat Detection & Automated Response Lab

![Status](https://img.shields.io/badge/Status-Completed-brightgreen?style=flat-square)
![Type](https://img.shields.io/badge/Type-Cloud%20Security%20Lab-blue?style=flat-square)
![Cloud](https://img.shields.io/badge/Cloud-AWS-FF9900?style=flat-square&logo=amazonaws&logoColor=white)
![Services](https://img.shields.io/badge/Services-GuardDuty%20%7C%20Lambda%20%7C%20EventBridge-orange?style=flat-square)
![IaC](https://img.shields.io/badge/IaC-None%20%28Console%29-lightgrey?style=flat-square)
![Focus](https://img.shields.io/badge/Focus-Blue%20Team%20%7C%20SOC%20Automation-purple?style=flat-square)

## Overview

This lab demonstrates the implementation of a **cloud-native security monitoring system** on Amazon Web Services, capable of detecting suspicious activity, generating automated alerts, and executing response actions — all without human intervention.

This project is part of a personal cybersecurity portfolio focused on **Cloud Security**, **SOC Automation**, and **Blue Team** practices.

---

## 🎯 Objective

Design and deploy an event-driven security pipeline that:

- Continuously monitors AWS account activity
- Detects anomalous or malicious behavior using intelligent threat detection
- Automatically notifies security personnel via email
- Executes automated response actions upon detection

---

## 🏗️ Architecture

```
User / Attacker
      ↓
CloudTrail → GuardDuty
      ↓
EventBridge (severity ≥ 9 filter)
      ↓
Lambda (security-response)
      ↓
SNS (email alert)
```

The pipeline follows an **event-driven architecture** where each AWS service acts as a discrete layer with a specific security responsibility:

| Layer | Service | Responsibility |
|-------|---------|----------------|
| Logging | CloudTrail | Records all API calls and account activity |
| Detection | GuardDuty | Analyzes logs and detects threats using ML |
| Routing | EventBridge | Filters and routes findings to response targets |
| Response | Lambda | Parses findings and publishes formatted alerts |
| Notification | SNS | Delivers alerts to subscribed email endpoints |

---

## ☁️ AWS Services Used

### CloudTrail
Records every action performed in the AWS account including logins, API calls, and IAM changes. Acts as the primary data source for the entire detection pipeline.

### GuardDuty
Intelligent threat detection service that continuously analyzes CloudTrail logs, VPC Flow Logs, and DNS logs. Uses machine learning models and threat intelligence feeds from AWS, CrowdStrike, and Proofpoint to identify suspicious behavior. Assigns a severity score from 1 to 10 to each finding.

### EventBridge
Serverless event bus that captures GuardDuty findings and routes them to Lambda. A custom event pattern filter ensures only **critical findings (severity ≥ 9)** trigger the response pipeline — reducing noise and preventing alert fatigue.

### Lambda
Serverless function written in Python 3.14 that:
- Parses the raw GuardDuty event
- Extracts relevant fields (threat type, severity, origin IP, region, account)
- Classifies severity into human-readable labels (🔴 HIGH / 🟠 MEDIUM / 🟡 LOW)
- Publishes a formatted alert to SNS
- Handles errors gracefully and logs to CloudWatch

### SNS (Simple Notification Service)
Pub/Sub notification service configured with an email subscription. Delivers formatted security alerts directly to the security analyst's inbox.

---

## 🔑 Key Technical Decisions

**IAM Least Privilege** — Instead of using the root account for daily operations, a dedicated IAM user (`andres`) was created and assigned to permission groups scoped by domain (`labs-security`, `labs-cloud`, `labs-dev`). This follows the principle of least privilege.

**MFA on Root** — Multi-factor authentication was enabled on the root account using Google Authenticator before any lab resources were provisioned.

**Filtering at EventBridge vs Lambda** — The severity filter (≥ 9) was implemented at the EventBridge level rather than inside Lambda. This is more efficient because Lambda is never invoked for low-severity findings, reducing unnecessary executions and cost.

**Environment Variables for Sensitive Config** — The SNS Topic ARN is stored as a Lambda environment variable (`SNS_TOPIC_ARN`) rather than hardcoded in the source code, following security best practices.

**SNS Standard vs FIFO** — Standard topic type was selected over FIFO because FIFO topics do not support email as a delivery protocol. For security alerting, strict message ordering is not a critical requirement.

**Same-Region Deployment** — All services (CloudTrail, GuardDuty, SNS, Lambda, EventBridge) were deployed in the same AWS region (us-east-2 / Ohio) to ensure cross-service compatibility and avoid latency.


---

## ✅ Lab Results

- GuardDuty successfully generated sample findings upon activation
- EventBridge correctly captured and routed findings matching the event pattern
- Lambda executed and parsed the GuardDuty event structure
- SNS delivered formatted email alerts to the configured endpoint
- End-to-end pipeline validated with sample findings generation

---

## 💰 Cost Considerations

| Service | Free Tier | Cost |
|---------|-----------|------|
| CloudTrail | 1 trail always free | $0 |
| GuardDuty | 30-day free trial | $0 (trial period) |
| SNS | 1M notifications/month | $0 |
| Lambda | 1M executions/month | $0 |
| EventBridge | AWS service events free | $0 |

> ⚠️ GuardDuty should be disabled after the lab to avoid charges once the 30-day trial expires.

---

## 🔧 Future Improvements

- [ ] Replace `IAMFullAccess` on `labs-security` group with a custom policy scoped to specific IAM actions required by the lab
- [ ] Add CloudWatch dashboard to visualize finding trends over time
- [ ] Implement automated remediation actions in Lambda (e.g., revoke IAM credentials upon critical finding)
- [ ] Integrate with AWS Security Hub for centralized finding management
- [ ] Add DLQ (Dead Letter Queue) to EventBridge for failed Lambda invocations
- [ ] Parameterize severity threshold via environment variable instead of hardcoded EventBridge pattern

---

## 🧹 Cleanup

To avoid ongoing charges after completing this lab:

1. **GuardDuty** → Settings → Disable GuardDuty
2. **Lambda** → Delete `security-response` function
3. **SNS** → Delete `security-alerts` topic
4. **EventBridge** → Delete `guardduty-rule`
5. **CloudTrail** → Stop logging on `lab-security-trail`
6. **S3** → Delete the auto-generated CloudTrail logs bucket

---

## 📚 References

- [AWS GuardDuty Documentation](https://docs.aws.amazon.com/guardduty/)
- [AWS EventBridge Documentation](https://docs.aws.amazon.com/eventbridge/)
- [AWS Lambda Documentation](https://docs.aws.amazon.com/lambda/)
- [AWS SNS Documentation](https://docs.aws.amazon.com/sns/)
- [IAM Best Practices](https://docs.aws.amazon.com/IAM/latest/UserGuide/best-practices.html)
