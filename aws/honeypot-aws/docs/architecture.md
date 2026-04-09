# Architecture Notes

## Full Flow

1. **EC2 with Cowrie** — simulates a vulnerable SSH server on port 22
2. **Real SSH** moved to port 2222 for administration
3. **Cowrie** logs every connection in structured JSON format
4. **CloudWatch Agent** ships logs to `/honeypot/cowrie` in real time
5. **CloudWatch Subscription Filter** triggers Lambda on each log batch
6. **Lambda analyzer** does five things:
   - Classifies the attack type
   - Queries ipinfo.io to geolocate the attacker IP
   - Saves a JSON report to S3
   - Sends an alert email via SNS
   - Blocks the IP in the Security Group

## Design Decisions

- **Port 22 for Cowrie** — bots scan port 22 by default, not 2222
- **Port 2222 for admin SSH** — allows instance management without interfering with the honeypot
- **CloudWatch instead of direct S3** — enables subscription filters and real-time analysis
- **setcap instead of authbind** — cleaner way to grant low-port permissions to Python
- **force_destroy on S3** — allows terraform destroy without errors even when reports exist

## Attack Classification Logic

```
log events
     ↓
5+ failed attempts? → SSH Brute Force
Successful login + commands? → SSH Intrusion + Command Execution
Successful login, no commands? → SSH Intrusion
Connection only? → SSH Probe
```

## Possible Improvements

- CloudWatch dashboard with attack metrics by country
- Slack integration in addition to email
- Command pattern analysis to detect malware families
- Full TTY session storage from Cowrie
- IP correlation with threat intelligence feeds (AbuseIPDB, VirusTotal)
