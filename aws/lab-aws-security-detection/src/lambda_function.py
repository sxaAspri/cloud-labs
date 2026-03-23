import json
import boto3
import os
from datetime import datetime

sns = boto3.client('sns')
SNS_TOPIC_ARN = os.environ.get('SNS_TOPIC_ARN')

def get_severity_label(severity):
    """Converts numeric severity score into a human-readable label."""
    if severity >= 7:
        return "🔴 HIGH"
    elif severity >= 4:
        return "🟠 MEDIUM"
    else:
        return "🟡 LOW"

def parse_guardduty_event(event):
    """Extracts relevant fields from the raw GuardDuty event."""
    detail = event.get('detail', {})

    finding_type    = detail.get('type', 'Unknown')
    severity_number = detail.get('severity', 0)
    severity_label  = get_severity_label(severity_number)
    region          = event.get('region', 'Unknown')
    account_id      = event.get('account', 'Unknown')
    description     = detail.get('description', 'No description available')

    ip_origen = (
        detail
        .get('service', {})
        .get('action', {})
        .get('networkConnectionAction', {})
        .get('remoteIpDetails', {})
        .get('ipAddressV4', 'Not available')
    )

    event_time = detail.get('updatedAt', datetime.utcnow().isoformat())

    return {
        'tipo'            : finding_type,
        'severidad_num'   : severity_number,
        'severidad_label' : severity_label,
        'region'          : region,
        'cuenta'          : account_id,
        'descripcion'     : description,
        'ip_origen'       : ip_origen,
        'hora'            : event_time
    }

def build_message(data):
    """Builds a human-readable alert message for the email notification."""
    return f"""
🚨 AWS SECURITY ALERT
{'='*40}

SEVERITY    : {data['severidad_label']} ({data['severidad_num']})
TYPE        : {data['tipo']}
REGION      : {data['region']}
ACCOUNT     : {data['cuenta']}
ORIGIN IP   : {data['ip_origen']}
TIME (UTC)  : {data['hora']}

DESCRIPTION :
{data['descripcion']}

{'='*40}
⚠️  Review your GuardDuty console for further details.
"""

def lambda_handler(event, context):
    print("Event received:", json.dumps(event))

    try:
        # 1. Parse the GuardDuty event
        data = parse_guardduty_event(event)

        # 2. Build human-readable message
        message = build_message(data)

        # 3. Set email subject based on severity
        subject = f"[AWS Security] {data['severidad_label']} Alert - {data['tipo'][:50]}"

        # 4. Publish to SNS
        sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Message=message,
            Subject=subject
        )

        print("Alert sent successfully")
        return {
            'statusCode': 200,
            'body': 'Alert sent'
        }

    except Exception as e:
        # Log error to CloudWatch and re-raise for visibility
        print(f"ERROR processing alert: {str(e)}")
        raise e