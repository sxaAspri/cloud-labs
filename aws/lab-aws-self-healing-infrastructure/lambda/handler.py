import boto3
import json
import os

ec2 = boto3.client('ec2')
sns = boto3.client('sns')

SNS_TOPIC_ARN = os.environ['SNS_TOPIC_ARN']
CLEAN_AMI_ID  = os.environ['CLEAN_AMI_ID']

def lambda_handler(event, context):
    # Extraer el finding de GuardDuty
    detail       = event.get('detail', {})
    finding_type = detail.get('type', 'Unknown')
    severity     = detail.get('severity', 0)
    region       = detail.get('region', 'us-east-1')

    # Obtener el ID de la instancia comprometida
    instance_id = (
        detail.get('resource', {})
              .get('instanceDetails', {})
              .get('instanceId')
    )

    # Publicar alerta por email
    mensaje = f"""
🚨 ALERTA DE SEGURIDAD - Self-Healing AWS Lab

Tipo de amenaza : {finding_type}
Severidad       : {severity}
Región          : {region}
Instancia       : {instance_id or 'No identificada'}

Respuesta automática iniciada...
    """

    sns.publish(
        TopicArn = SNS_TOPIC_ARN,
        Subject  = f"🚨 GuardDuty Finding - Severidad {severity}",
        Message  = mensaje
    )

    # Auto-recuperación — solo si hay instancia comprometida
    if instance_id:
        # 1. Terminar instancia comprometida
        ec2.terminate_instances(InstanceIds=[instance_id])
        print(f"Instancia {instance_id} terminada")

        # 2. Lanzar instancia limpia desde AMI
        nueva = ec2.run_instances(
            ImageId      = CLEAN_AMI_ID,
            InstanceType = 't2.micro',
            MinCount     = 1,
            MaxCount     = 1,
            TagSpecifications=[{
                'ResourceType': 'instance',
                'Tags': [
                    {'Key': 'Name',    'Value': 'self-healing-recovered'},
                    {'Key': 'Project', 'Value': 'self-healing-aws'}
                ]
            }]
        )

        nueva_id = nueva['Instances'][0]['InstanceId']
        print(f"Nueva instancia lanzada: {nueva_id}")

        # Notificar recuperación
        sns.publish(
            TopicArn = SNS_TOPIC_ARN,
            Subject  = "✅ Recuperación completada",
            Message  = f"Instancia comprometida {instance_id} reemplazada por {nueva_id} usando AMI limpia {CLEAN_AMI_ID}"
        )

    return {'statusCode': 200, 'body': 'Respuesta ejecutada correctamente'}
