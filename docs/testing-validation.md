# Testing and Validation

This guide validates every security control in the Accountable Automation Framework. It confirms that identity separation, scoped permissions, credential storage, and audit trail attribution behave as expected.

All tests are designed to be repeatable and portable, proving that the identity layer makes actions attributable by design.

### 1. Prerequisites

Before running tests:

### Deploy the infrastructure
Terraform deployment must be complete and successful.

### Retrieve the Windows Administrator password
See deployment.md step 7.

### Configure the human user CLI profile
See deployment.md step 10.

### Verify AWS CLI connectivity
From the Windows instance PowerShell:

```powershell
aws sts get-caller-identity
```

Expected — automation role identity:

```json
{
    "UserId": "AROAXXXXXXXXXX:aaf-windows",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:sts::YOUR_ACCOUNT_ID:assumed-role/AutomationRole/aaf-windows"
}
```

With the human user profile:

```powershell
aws sts get-caller-identity --profile human-user
```

Expected — human user identity:

```json
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:iam::YOUR_ACCOUNT_ID:user/aaf-human-user"
}
```

### 2. Test 1 — Identity Separation (ListUsers)

The goal is to confirm that the same action performed by two principals produces two distinct CloudTrail entries.

### Run as automation role (instance profile — default):

```powershell
aws iam list-users
```

### Run as human user (named profile — explicit):

```powershell
aws iam list-users --profile human-user
```

### Query CloudTrail from the bastion:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ListUsers \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

Expected output — same action, two identities:

```
+-------------------------+-----------------------------+----------+
|          Time           |            User             |  Event   |
+-------------------------+-----------------------------+----------+
| 2026-XX-XXT10:17:45Z   | aaf-human-user              | ListUsers|
| 2026-XX-XXT10:15:22Z   | AutomationRole              | ListUsers|
+-------------------------+-----------------------------+----------+
```

This is the receipt. Two principals. Zero ambiguity.

### 3. Test 2 — Least Privilege Enforcement (Denied Actions)

The goal is to confirm the automation role cannot exceed its scoped permissions.

### Attempt to enable CloudTrail (explicitly denied):

```powershell
aws cloudtrail start-logging --name aaf-trail
```

Expected:

```
An error occurred (AccessDeniedException) when calling the StartLogging operation: 
User: arn:aws:sts::...:assumed-role/AutomationRole/... is not authorized to perform: 
cloudtrail:StartLogging
```

### Attempt to create an EBS snapshot (explicitly denied):

```powershell
aws ec2 create-snapshot --volume-id YOUR_VOLUME_ID
```

Expected:

```
An error occurred (UnauthorizedOperation) when calling the CreateSnapshot operation:
You are not authorized to perform this operation.
```

### Query denied actions in CloudTrail from the bastion:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartLogging \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

Expected — denied action logged under automation role identity:

```
+-------------------------+--------------------+---------------+
|          Time           |        User        |     Event     |
+-------------------------+--------------------+---------------+
| 2026-XX-XXT10:20:11Z   | AutomationRole     | StartLogging  |
+-------------------------+--------------------+---------------+
```

The boundary held. The attempt is recorded.

### 4. Test 3 — Secrets Manager Credential Retrieval

The goal is to confirm the automation role can retrieve credentials from Secrets Manager and that the retrieval is logged.

### Retrieve the secret:

```powershell
aws secretsmanager get-secret-value --secret-id openclaw/automation/ai-service-api-key
```

Expected:

```json
{
    "Name": "openclaw/automation/ai-service-api-key",
    "SecretString": "{\"api_key\":\"...\",\"service\":\"openclaw-ai-service\"}"
}
```

### Query CloudTrail from the bastion:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=GetSecretValue \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

Expected — retrieval logged under automation role identity with secret ARN in request parameters.

### 5. Test 4 — S3 Prefix Enforcement

The goal is to confirm each principal is scoped to its designated prefix and cannot access the other's lane.

### Automation role writes to automation/ prefix (permitted):

```powershell
"automation test" | Out-File C:\workflow\automation\test.txt
aws s3 cp C:\workflow\automation\test.txt s3://YOUR_WORKFLOW_BUCKET/automation/
```

Expected: upload succeeds.

### Automation role attempts to write to human/ prefix (denied):

```powershell
aws s3 cp C:\workflow\automation\test.txt s3://YOUR_WORKFLOW_BUCKET/human/
```

Expected:

```
An error occurred (AccessDenied) when calling the PutObject operation: Access Denied
```

### Human user writes to human/ prefix (permitted):

```powershell
"human test" | Out-File C:\workflow\human\test.txt
aws s3 cp C:\workflow\human\test.txt s3://YOUR_WORKFLOW_BUCKET/human/ --profile human-user
```

Expected: upload succeeds.

### 6. Test 5 — Human User Instance Reboot

The goal is to confirm the human user can reboot the workflow instance and that the action is logged under the human user identity.

```powershell
$instanceId = (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 reboot-instances --instance-ids $instanceId --profile human-user
```

Expected: reboot initiates. Query CloudTrail to confirm the action is logged under `aaf-human-user`.

### 7. Test 6 — Tamper-Proof Audit Trail

The goal is to confirm neither principal can modify or disable the audit trail.

### Automation role attempts to stop logging (denied by permissions boundary):

```powershell
aws cloudtrail stop-logging --name aaf-trail
```

Expected: AccessDeniedException.

### Human user attempts to write to the CloudTrail logs bucket (denied by bucket policy):

```powershell
"test" | Out-File C:\test.txt
aws s3 cp C:\test.txt s3://YOUR_CLOUDTRAIL_BUCKET/ --profile human-user
```

Expected: AccessDenied. The bucket policy permits only the CloudTrail service to write.

### 8. Test 7 — Full Attribution Query

The goal is to retrieve the complete audit trail for both principals from the bastion host. SSH into the bastion and run each query individually. Wait 5 to 15 minutes after running the proof of concept actions before querying — CloudTrail has a delivery delay.

List all ListUsers events by principal — confirms the same action produced two distinct identity entries:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ListUsers \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

List all denied actions — confirms the automation role boundary held and the attempts were recorded:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartLogging \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

List all activity attributed to the automation role — confirms the complete automation trail under a single named identity:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=AutomationRole \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
  --output table
```

List all activity attributed to the human user — confirms the complete human trail under a separate named identity:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=aaf-human-user \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
  --output table
```

This is your complete receipt. Two principals. Every action attributed. Zero ambiguity.

### 9. Summary Checklist

You should now be able to check off:

- Identity separation confirmed — same action, two distinct CloudTrail entries
- Least privilege enforced — denied actions logged under automation role identity
- Secrets Manager retrieval working — logged with principal identity and secret ARN
- S3 prefix enforcement confirmed — each principal scoped to its own lane
- Human user instance reboot working — logged under human user identity
- Tamper-proof audit trail confirmed — neither principal can modify the trail
- Full attribution query successful — complete two-principal receipt retrieved from bastion

These tests collectively verify the framework makes identity boundaries legible, enforces them architecturally, and produces an audit trail that knows the difference between a human action and an automated one.
