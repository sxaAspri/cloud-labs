import boto3
import json
import os
import urllib.request
from datetime import datetime

s3  = boto3.client('s3')
sns = boto3.client('sns')

BUCKET_NAME   = os.environ['BUCKET_NAME']
SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']

def get_ip_info(ip):
    try:
        url = f"https://ipinfo.io/{ip}/json"
        req = urllib.request.urlopen(url, timeout=3)
        return json.loads(req.read().decode())
    except:
        return {}

def classify_attack(events):
    commands   = [e.get('input', '') for e in events if e.get('eventid') == 'cowrie.command.input']
    failed     = [e for e in events if e.get('eventid') == 'cowrie.login.failed']
    successful = [e for e in events if e.get('eventid') == 'cowrie.login.success']

    if len(failed) >= 5:
        attack_type = "SSH Brute Force"
    elif successful and commands:
        attack_type = "SSH Intrusion + Command Execution"
    elif successful:
        attack_type = "SSH Intrusion"
    else:
        attack_type = "SSH Probe"

    return attack_type, commands

def block_ip(ip, security_group_id):
    ec2_client = boto3.client('ec2')
    try:
        ec2_client.revoke_security_group_ingress(
            GroupId    = security_group_id,
            IpProtocol = 'tcp',
            FromPort   = 22,
            ToPort     = 22,
            CidrIp     = f"{ip}/32"
        )
    except:
        pass
    try:
        ec2_client.authorize_security_group_ingress(
            GroupId    = security_group_id,
            IpProtocol = '-1',
            FromPort   = -1,
            ToPort     = -1,
            CidrIp     = f"{ip}/32"
        )
    except Exception as e:
        print(f"Error bloqueando {ip}: {e}")

def lambda_handler(event, context):
    import base64, gzip

    log_data     = event.get('awslogs', {}).get('data', '')
    decoded      = base64.b64decode(log_data)
    uncompressed = gzip.decompress(decoded)
    log_events   = json.loads(uncompressed)

    events = []
    src_ip = None

    for log_event in log_events.get('logEvents', []):
        try:
            data = json.loads(log_event['message'])
            events.append(data)
            if not src_ip and data.get('src_ip'):
                src_ip = data['src_ip']
        except:
            continue

    if not src_ip or not events:
        return {'statusCode': 200, 'body': 'No events to process'}

    attack_type, commands = classify_attack(events)
    ip_info = get_ip_info(src_ip)

    reporte = {
        'timestamp'   : datetime.utcnow().isoformat(),
        'src_ip'      : src_ip,
        'country'     : ip_info.get('country', 'Unknown'),
        'city'        : ip_info.get('city', 'Unknown'),
        'org'         : ip_info.get('org', 'Unknown'),
        'attack_type' : attack_type,
        'commands'    : commands,
        'total_events': len(events)
    }

    key = f"reports/{datetime.utcnow().strftime('%Y/%m/%d')}/{src_ip}_{datetime.utcnow().strftime('%H%M%S')}.json"
    s3.put_object(
        Bucket      = BUCKET_NAME,
        Key         = key,
        Body        = json.dumps(reporte, indent=2),
        ContentType = 'application/json'
    )

    mensaje = f"""
HONEYPOT — Ataque detectado

IP atacante  : {src_ip}
País         : {reporte['country']}
Ciudad       : {reporte['city']}
Organización : {reporte['org']}
Tipo         : {attack_type}
Comandos     : {', '.join(commands) if commands else 'Ninguno'}
Eventos      : {len(events)}

Reporte completo en S3: {key}
    """

    sns.publish(
        TopicArn = SNS_TOPIC_ARN,
        Subject  = f"Honeypot — {attack_type} desde {src_ip}",
        Message  = mensaje
    )

    # Auto-bloqueo de la IP atacante
    sg_id = os.environ.get('SECURITY_GROUP_ID')
    if sg_id:
        block_ip(src_ip, sg_id)

    return {'statusCode': 200, 'body': f'Reporte guardado: {key}'}
