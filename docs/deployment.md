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

4. Press Enter

5. From there, click on "Show Options" at the lower left corner and then on the "Local Resources" tab.

6. Click on More and check the box next to Drives

7. Click OK when you're done


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

### 10. Connect to the Windows instance via RDP

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
New-Item -Path c:\workflow -ItemType Directory.
```
This is where both principals will be staging files before uploading them to S3.

### 13. Configure the Human User Profile on the Windows Instance

The Windows instance inherits the automation role by default through its instance profile. The human user identity must be configured explicitly as a named profile, requiring a conscious act to invoke it.
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

### 14. Teardown Sequence

Run teardown in order. Skipping steps will cause terraform destroy to fail on versioned S3 buckets.


**View and clear Secrets Manager**

List secrets:
```
aws secretsmanager list-secrets
```

Delete secrets:
```
aws secretsmanager delete-secret --secret-id openclaw/automation/ai-service-api-key --force-delete-without-recovery
```

**View and clear the S3 workflow bucket**

List contents:
```
aws s3 ls s3://<workflow_bucket_name> --recursive
```

Remove all objects:
```
aws s3 rm s3://<workflow_bucket_name> --recursive
```

**View and clear the S3 logs bucket**

List contents
```
aws s3 ls s3://<logs_bucket_name> --recursive
```

Remove all objects
```
aws s3 rm s3://<logs_bucket_name> --recursive
```

**Clear all versioning from each bucket**

Both buckets have versioning enabled. Deleting objects leaves delete markers and version history behind. Use the following script to purge all versions and delete markers from a bucket before destroying:
```
$bucket = "<your_bucket_name>"

$versions = aws s3api list-object-versions --bucket $bucket | ConvertFrom-Json

foreach ($v in $versions.Versions) {
    aws s3api delete-object --bucket $bucket --key $v.Key --version-id $v.VersionId
}
Running this script once for each S3 bucket (logs and workflow) substituting the correct bucket name as applicable.
```

**Destroy the infrastructure**
```
terraform destroy
```
Confirm `yes` when prompted. Destruction takes approximately 3 to 5 minutes.

foreach ($m in $versions.DeleteMarkers) {
    aws s3api delete-object --bucket $bucket --key $m.Key --version-id $m.VersionId
}
```

