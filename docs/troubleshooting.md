# Troubleshooting

A few issues you might run into while deploying or tearing down the Accountable Automation Framework and how to fix them.

### Terraform destroy fails because S3 bucket is not empty

You may see an error similar to:

> Error deleting S3 Bucket (...) BucketNotEmpty: The bucket you tried to delete is not empty. You must delete all versions in the bucket.

Because versioning is enabled, a standard `aws s3 rm --recursive` removes current objects but leaves previous versions and delete markers behind. AWS refuses to delete a non-empty versioned bucket.

### Fix

First identify the object versions in the bucket:

```powershell
aws s3api list-object-versions --bucket YOUR_BUCKET_NAME
```

Then delete each version directly using the exact Key and VersionId from the output:

```powershell
aws s3api delete-object --bucket YOUR_BUCKET_NAME --key "EXACT_KEY" --version-id "EXACT_VERSION_ID"
```

For delete markers with a null VersionId:

```powershell
aws s3api delete-object --bucket YOUR_BUCKET_NAME --key "EXACT_KEY" --version-id "null"
```

Repeat for each version and delete marker until `list-object-versions` returns empty. Then retry `terraform destroy`.

### Suppressing variable prompts for repeated deployments

By design, the Accountable Automation Framework prompts for variable input at each `terraform plan` and `terraform apply`. This is intentional, the prompt sequence is a mindfulness trigger requiring conscious confirmation of each value before infrastructure changes are applied.

If you are running repeated deployments and want to suppress the prompts, you can create a `terraform.tfvars` file in your project directory:

```hcl
aws_region             = "us-east-1"
admin_ip               = "YOUR_IP_ADDRESS/32"
key_pair_name          = "your-key-pair-name"
cloudtrail_bucket_name = "aaf-cloudtrail-logs-SUFFIX"
workflow_bucket_name   = "aaf-workflow-SUFFIX"
ai_service_api_key     = "your-api-key-value"
```

Terraform will read this file automatically and skip the prompts. Do not commit `terraform.tfvars` to version control — it is listed in `.gitignore` by default.

### Invalid CIDR block error for admin_ip

You may see:

> Error: "YOUR_IP_ADDRESS/32" is not a valid CIDR block

### Fix

Open `terraform.tfvars` and confirm your IP address is quoted as a string and includes the /32 suffix:

```hcl
admin_ip = "203.0.113.1/32"
```

Retrieve your current public IP by going to whatismyipaddress.com or api.ipify.org

### Key pair not found error during terraform apply

You may see:

> Error: creating EC2 Instance: InvalidKeyPair.NotFound: The key pair 'name' does not exist

### Fix

Confirm the key pair exists in your AWS console under EC2 — Key Pairs in the same region you are deploying to. The name in `terraform.tfvars` must match exactly, no `.pem` extension, case sensitive.

```hcl
key_pair_name = "bastion-key-2"
```

Not:

```hcl
key_pair_name = "bastion-key-2.pem"
```

### Windows Administrator password not available immediately

After `terraform apply` completes, the Windows instance needs 5 to 10 minutes to finish initialization before the Administrator password is available in the AWS console.

If you see an error retrieving the password, wait a few minutes and try again.

### CloudTrail lookup returns no results immediately after running scripts

CloudTrail has a delivery delay of approximately 5 to 15 minutes before events appear in lookup queries. If your `query-cloudtrail.sh` script returns empty tables immediately after running the proof of concept scripts, wait a few minutes and run it again.

## Security group duplicate resource error during terraform validate

If you see a duplicate resource error for a security group, you may have conflicting `.tf` files in your directory — for example, a `network.tf` from a previous iteration alongside the current `main.tf`.

### Fix

Run the following to find all security group declarations across your files:

```powershell
Select-String -Path "*.tf" -Pattern "resource.*aws_security_group"
```

Identify which file contains the duplicate and remove it. Each security group resource name must appear exactly once across all `.tf` files in the directory.

### S3 bucket name already exists

S3 bucket names are globally unique across all AWS accounts. If your chosen bucket name is already taken you will see a bucket creation error.

### Fix

Update both bucket name variables in `terraform.tfvars` with a unique suffix:

```hcl
cloudtrail_bucket_name = "aaf-cloudtrail-logs-YOUR_SUFFIX"
workflow_bucket_name   = "aaf-workflow-YOUR_SUFFIX"
```

Your AWS account ID or initials work well as a suffix.
