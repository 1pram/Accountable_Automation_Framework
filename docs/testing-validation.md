# Testing and Validation

This guide validates every security control in the Accountable Automation Framework. It confirms that identity separation, scoped permissions, credential storage, and audit trail attribution behave as expected.

All tests are designed to be repeatable and produce clear pass or fail outcomes.


**Prerequisites**

Before running the tests:

- Terraform deployment must be complete and successful

- Windows administrator password must be retrieved from the AWS console

- SSH tunnel and RDP session must be active on the Windows instance

- AWS CLI must be installed on the Windows instance

- Human user CLI profile must be configured


**Verify both identities are reachable from the Windows instance:**
```
aws sts get-caller-identity
```

Expected automation role:
```
{
    "UserId": "AROAXXXXXXXXXX:i-XXXXXXXXXX",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:sts::YOUR_ACCOUNT_ID:assumed-role/AutomationRole/i-XXXXXXXXXX"
}
```

With the human user profile:

```
aws sts get-caller-identity --profile human-user
```

Expected human user identity:

```
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:iam::YOUR_ACCOUNT_ID:user/aaf-human-user"
}
```

**Test 1 SSH into the bastion**

From your local machine, confirm SSH access to the bastion/jump host:
```
ssh -i <YOUR_KEY_PAIR_FILE'S_NAME.pem> ec2-user@<BASTION'S_PUBLIC_IP>
```
Expected: successful login to the bastion
This confirms the bastion is reachable from the Internet on port 22 and that your key pair is valid.

**Test 2 SSH attempt into the Windows instance**

From your local machine:
```
ssh -i <YOUR_KEY_PAIR_FILE'S_NAME.pem> ec2-user@<WINDOWS INSTANCE'S_PRIVATE_IP>
```
Expected: connection times out or is refused
The Windows instance has no public IP and its security group does not permit inbound SSH from the Internet. The only path in is through the bastion tunnel/funnel.

**Test 3 SSH attempt into the bastion from the Windows instance**

`ssh ec2-user@<BASTION'S_IP>`

Expected: connection refused or permission denied.
The bastion security group does not permit inbound SSH from the private subnet.
Traffic flows one way, inbound from the Internet to the bastion, then forwarded to the Windows instance. The Windows instance cannot initiate connections back to the bastion.

**Test 4 Automation role writes to Automation Prefix**

1. From the Windows instance, create a file and upload it to the automation prefix using the default instance profile:

2. Open PowerShell and type or copy and paste:
```
"Run down of today's tasks" | Out-File C:\Workflow\todolist.txt
aws s3 cp C:\Workflow\todolist.txt s3://<WORKFLOW_BUCKET>/automation/
```
Expected: A successful upload confirms the automation role has write access to its designated prefix/folder of directory. 

**Test 5 Automation role attempts to write to the human prefix**

From the Windows instance, type: `aws s3 cp c:\workflow\todolist.txt s3://<WORKFLOW_BUCKET>/human/`

Expected: An error occurred (Access denied) when calling the PutObject operation

**Test 6 Human user writes to the human prefix**

Create a file and upload it to the human prefix:
```
"Automation performance report" | Out-file: c:\workflow\report.txt
aws s3 cp c:\workflow\report.txt s3://<WORKFLOW_BUCKET>/human/
```
Expected: A successful upload confirms the human user has write access to its designated prefix/folder of directory. 

**Test 7 Human user attempts CloudTrail lookup**

Type or copy and past: `aws cloudtrail lookup-events --lookup-attributes AttributeKey=EventName,AttributeValue=PutObject --output table --profile human-user`

Expected: An error occurred (AccessDeniedException)...
The human user's IAM policy does not include CloudTrail permissions. Only the bastion can query the the audit trail. 

**Test 8 SSH into the Bastion to access raw logs**

1. From your local machine:
```
ssh -i <YOUR_KEY_PAIR_FILE'S_NAME> ec2-user@<BASTION'S_PUBLIC_IP>
```
   The bastion host carries the instance profile with CloudTrail and S3 read permissions. All CloudTrail queries and log inspection are performed from  
   here.
2. From the bastion, list the CloudTrail log files delivered to S3
```
aws s3 ls s3://<CLOUDTRAIL_BUCKET>/AWSLogs/<ACCOUNT_ID>/CloudTrail/us-east-1/ --recursive | tail -20
```
Expected: a list of .json.gz files timestamped at roughly 5-minute intervals confirming CloudTrail is actively writing logs.

Note: S3 data events may take up to 15 minutes to appear after the action occurs. Management events typically appear faster.

**Test 9 Inspect raw logs for PutObject attribution**




