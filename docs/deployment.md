# Deployment Guide

This guide walks through deploying the Accountable Automation Framework using Terraform. The build includes a VPC, two EC2 instances, three IAM principals, two S3 buckets, AWS Secrets Manager, CloudTrail, and three VPC endpoints.

### 1. Tech Stack

- **AWS** Cloud provider hosting all infrastructure components
- **Terraform** Infrastructure as Code tool used to define, plan, and deploy the entire environment
- **VSCode** Code editor used to write and manage Terraform configuration files
- **Draw.io** Used to design the infrastructure dataflow diagrams
- **eraser.io** Used to generate the cloud architecture diagrams
- **OWASP Threat Dragon** Used to build and export the formal STRIDE threat model

### 2. Prerequisites

- Terraform v1.5 or later
- AWS CLI v2
- An existing EC2 key pair in your target AWS region
- IAM permissions to create: VPC, EC2, IAM, S3, Secrets Manager, CloudTrail, VPC Endpoints

Download your EC2 key pair `.pem` file into the project directory alongside your `.tf` files. The name is your choice. Be sure to reference it consistently in the commands below.

### Verify tools

From the terminal in VSCode:

```
terraform --version
aws --version
aws sts get-caller-identity
```

### Clone the repository

```
git clone https://github.com/<your-repo>/accountable-automation-framework.git
cd accountable-automation-framework
```

### 3. Project Structure

```
Accountable_Automation_Framework/
|
|-- README.md
|
|-- providers.tf
|-- variables.tf
|-- outputs.tf
|
|-- vpc.tf
|-- subnets.tf
|-- main.tf
|-- endpoints.tf
|-- iam.tf
|-- s3.tf
|-- secrets.tf
|-- cloudtrail.tf
|-- instances.tf
|
|-- docs/
|   |-- architecture.md
|   |-- deployment.md
|   |-- testing-validation.md
|   |-- limitations.md
|   |-- troubleshooting.md
|   |-- threat-model.md
|
|-- diagrams/
|   |-- dual-identity-dataflow.png
|   |-- tiered-identity-dataflow.png
|   |-- infrastructure-diagram.png
|   |-- identity-observability-diagram.png
```

### 4. Initialize Terraform

```
terraform init
```

You should see:

```
Terraform has been successfully initialized!
```

If a provider version mismatch occurs, update your lock file or Terraform version accordingly.

### 5. Validate and Plan

### Validate syntax:

```
terraform validate
```

Expected:

```
Success! The configuration is valid.
```

### Generate the execution plan:

```
terraform plan -out=tfplan
```

Terraform prompts for 5 variables (Enter each one when asked):

```
- Your public IPv4 in CIDR form for SSH to bastion (e.g., 203.0.113.25/32. This can be retrieved by going to whatismyipaddress.com or api.ipify.org)

- var.ai_service_api_key (A mock API key e.g. sk-oc-mock-a7f3d2e8b1c94f6a8e2d5b7c3f1a9e4d use this exact string)

- var.cloudtrail_bucket_name (The S3 Logs bucket name. It must be globally unique. Append your account ID or initials)

- key_name The name of your EC2 key pair (Without the .pem extension)

- var.workflow_bucket_name (the S3 workflow bucket name. This will be used by the human-user and automation role. It must be globally unique. Add your account ID or initials)
```

Look for approximately:

```
Plan: 24 to add, 0 to change, 0 to destroy.
```

### 6. Apply the Infrastructure

```
terraform apply tfplan
```

You will be prompted for the same five values as during plan. Type `yes` when asked to confirm.

On success you should see outputs like:

```
bastion_public_ip       = "x.x.x.x"
windows_private_ip      = "10.0.1.x"
human_user_access_key   = "AKIAXXXXXXXXXX"
cloudtrail_bucket       = "aaf-cloudtrail-logs-SUFFIX"
workflow_bucket         = "aaf-workflow-SUFFIX"
secrets_manager_arn     = "arn:aws:secretsmanager:..."
automation_role_arn     = "arn:aws:iam::...:role/AutomationRole"
```

Retrieve your IP values for use in subsequent steps:

```
terraform output bastion_public_ip
terraform output windows_private_ip
```
### 7. Prepping your host device for file sharing with the Windows instance

1. On your local machine, use the browser to download the AWS CLI installer at: https://awscli.amazonaws.com/AWSCLIV2.msi

2. Move the file to the C: drive's Drivers folder

3. Click on the Windows Key, then on Run, and you will type: mstsc

4. From there, click on "Show Options" near the lower left corner and then on the "Local Resources" tab.

5. Click on More and check the box next to Drives

6. Click OK when you're done


### 8. Open the SSH tunnel to RDP

From your local terminal, open a tunnel to forward RDP traffic through the bastion to the Windows instance:
```
ssh -i bastion-key-2.pem -L 3389:<WINDOWS_PRIVATE_IP>:3389 ec2-user@<BASTION_PUBLIC_IP> -N
```
Leave the terminal open. The tunnel must remain active for the duration of your RDP session.

### 9. Retrieve the Windows Administrator Password

The Windows instance generates a random Administrator password encrypted with your key pair.

In the AWS console:

1. Go to EC2 - Instances
2. Select the `aaf-windows` instance
3. Actions -> Security -> Get Windows Password
4. Upload your `.pem` file
5. Copy the decrypted password

Wait 5 to 10 minutes after the instance launches before attempting to retrieve the password - the instance needs time to complete initialization.

### 10. Connect via RDP

1. With the tunnel open, go back to the RDP screen, click on Connect then on Connect.
2. Log in as Administrator using the password retrieved in the previous step.

### 11. Retrieving and installing the AWS CLI 

1. On the Windows instance, navigate to where you copied the AWSCLIV2.msi (Windows Explorer-> This PC -> your shared drive -> Drivers
2. Move AWSCLI2.msi to the instance's Desktop and run the installer.
3. Once completed, open PowerShell to verify setup,
   type:
```
aws --version
```

### 12. Create the workflow folder

From the PowerShell screen on the Windows instance, create the local working directory:
```
New-Item -Path c:\workflow ItemType Directory.
```
This is where both principals will be staging files before uploading them to S3.

### 13. Configure the Human User Profile on the Windows Instance

On the same PowerShell screen, run:

```
aws configure --profile human-user
```

Enter when prompted:

```
AWS Access Key ID:     (from terraform output human_user_access_key)
AWS Secret Access Key: (run: terraform output human_user_secret_key)
Default region name:   us-east-1
Default output format: json
```

### 11. Automation Role Actions

The instance carries the automation role by default via the instance profile. No profile flag is needed. Run each command from PowerShell.

List all IAM users in the account - confirms the automation role has enumeration access:

```powershell
aws iam list-users
```

Write a log file to the automation prefix in the workflow bucket - confirms scoped S3 write access:

```powershell
"automation log" | Out-File C:\workflow\automation\log.txt
aws s3 cp C:\workflow\automation\log.txt s3://YOUR_WORKFLOW_BUCKET/automation/
```

Retrieve the AI service API key from Secrets Manager - confirms encrypted credential retrieval:

```powershell
aws secretsmanager get-secret-value --secret-id openclaw/automation/ai-service-api-key
```

The following two actions are outside the automation role's defined scope. Both will return an access denied error - confirming the permissions boundary is holding.

Attempt to enable CloudTrail logging:

```powershell
aws cloudtrail start-logging --name aaf-trail
```

Attempt to create an EBS snapshot:

```powershell
aws ec2 create-snapshot --volume-id YOUR_VOLUME_ID
```

Your volume ID can be retrieved from the terminal:

```powershell
aws ec2 describe-volumes --query 'Volumes[0].VolumeId' --output text
```

### 12. Human User Actions

The human user profile must be invoked explicitly. Add `--profile human-user` to each command.

List all IAM users in the account - the same action as the automation role, logged under a different identity:

```powershell
aws iam list-users --profile human-user
```

Write a file to the human prefix in the workflow bucket - confirms the human user's scoped S3 write access:

```powershell
"human file" | Out-File C:\workflow\human\file.txt
aws s3 cp C:\workflow\human\file.txt s3://YOUR_WORKFLOW_BUCKET/human/ --profile human-user
```

Reboot the workflow instance - confirms the human user's instance management permission:

```powershell
aws ec2 reboot-instances --instance-ids YOUR_INSTANCE_ID --profile human-user
```

Your instance ID can be retrieved from the instance metadata endpoint:

```powershell
Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id
```

### 13. Query CloudTrail from the Bastion

SSH back into the bastion and run each query individually. CloudTrail has a delivery delay of approximately 5 to 15 minutes - if results are empty, wait and try again.

List all ListUsers events grouped by principal reveals that the same action was performed by two distinct identities:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=ListUsers \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

List all denied actions reveals that the automation role's boundary held and the attempt was recorded:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=EventName,AttributeValue=StartLogging \
  --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
  --output table
```

List all activity attributed to the automation role reveals the complete automation trail under a single named identity:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=AutomationRole \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
  --output table
```

List all activity attributed to the human user reveals the complete human trail under a separate named identity:

```bash
aws cloudtrail lookup-events \
  --lookup-attributes AttributeKey=Username,AttributeValue=aaf-human-user \
  --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
  --output table
```

See `testing-validation.md` for expected outputs and the full validation workflow.

### 14. Cleanup

When done, empty the versioned S3 buckets before destroying. List object versions first:

```powershell
aws s3api list-object-versions --bucket YOUR_CLOUDTRAIL_BUCKET
```

Delete each version using the exact Key and VersionId from the output:

```powershell
aws s3api delete-object --bucket YOUR_CLOUDTRAIL_BUCKET --key "YOUR_KEY" --version-id "YOUR_VERSION_ID"
```

For delete markers with a null VersionId:

```powershell
aws s3api delete-object --bucket YOUR_CLOUDTRAIL_BUCKET --key "YOUR_KEY" --version-id "null"
```

Then destroy the infrastructure:

```bash
terraform destroy
```

If deletion fails due to versioned objects, follow the instructions in `troubleshooting.md`.
