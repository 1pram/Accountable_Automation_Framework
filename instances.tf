# compute.tf
# Two EC2 instances with distinct purposes
# Windows Server 2022 - OpenClaw execution environment simulation
# Amazon Linux 2023 bastion - single controlled entry point and CloudTrail observation

# -------------------
# Existing SSH Key Pair
# References your existing key pair - no new key generated
# -------------------

data "aws_key_pair" "bastion" {
  key_name = "your-existing-key-pair-name"
}

# -------------------
# Windows Server 2022
# Private subnet - no direct internet access
# Automation role via instance profile (default)
# Human user via named CLI profile (explicit)
# Both principals demonstrated from single RDP session
# -------------------

data "aws_ami" "windows_2022" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["Windows_Server-2022-English-Full-Base-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "windows" {
  ami                    = data.aws_ami.windows_2022.id
  instance_type          = "t3.medium"
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.windows_instance.id]
  iam_instance_profile   = aws_iam_instance_profile.automation.name

  # EBS root volume - operating system only
  # Credential storage moved to Secrets Manager
  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name    = "tiered-identity-windows-os"
      Purpose = "Operating system volume only - not credential storage"
    }
  }

  # User data - installs AWS CLI and creates proof of concept scripts
  user_data = <<-EOF
    <powershell>
    # Install AWS CLI
    $url = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $output = "C:\AWSCLIV2.msi"
    Invoke-WebRequest -Uri $url -OutFile $output
    Start-Process msiexec.exe -Wait -ArgumentList '/I C:\AWSCLIV2.msi /quiet'

    # Create workflow directories
    New-Item -ItemType Directory -Force -Path "C:\workflow\human"
    New-Item -ItemType Directory -Force -Path "C:\workflow\automation"

    # Automation role script - runs as instance profile by default
    $automationScript = @"
    # Automation role actions
    # Runs as instance profile - no profile flag needed
    Write-Host "=== Running as automation role (instance profile) ==="

    Write-Host "1. ListUsers - permitted"
    aws iam list-users

    Write-Host "2. Writing to automation prefix - permitted"
    "automation log $(Get-Date)" | Out-File C:\workflow\automation\log.txt
    aws s3 cp C:\workflow\automation\log.txt s3://tiered-identity-workflow/automation/

    Write-Host "3. GetSecretValue - permitted"
    aws secretsmanager get-secret-value --secret-id openclaw/automation/ai-service-api-key

    Write-Host "4. StartLogging - explicitly denied"
    aws cloudtrail start-logging --name tiered-identity-trail

    Write-Host "5. CreateSnapshot - explicitly denied"
    aws ec2 create-snapshot --volume-id (aws ec2 describe-volumes --query 'Volumes[0].VolumeId' --output text)
    "@
    $automationScript | Out-File "C:\workflow\automation\run-automation.ps1"

    # Human user script - uses named profile explicitly
    $humanScript = @"
    # Human user actions
    # Uses named profile - configure first with: aws configure --profile human-user
    Write-Host "=== Running as human user (named profile) ==="

    Write-Host "1. ListUsers - permitted"
    aws iam list-users --profile human-user

    Write-Host "2. Writing to human prefix - permitted"
    "human file $(Get-Date)" | Out-File C:\workflow\human\file.txt
    aws s3 cp C:\workflow\human\file.txt s3://tiered-identity-workflow/human/ --profile human-user

    Write-Host "3. RebootInstances - permitted"
    aws ec2 reboot-instances --instance-ids (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id) --profile human-user
    "@
    $humanScript | Out-File "C:\workflow\human\run-human.ps1"

    # README for RDP session
    $readme = @"
    TIERED IDENTITY PROOF OF CONCEPT
    =================================

    STEP 1 - Configure human user profile:
    aws configure --profile human-user
    (Use access key and secret key from Terraform outputs)

    STEP 2 - Run automation role actions:
    C:\workflow\automation\run-automation.ps1

    STEP 3 - Run human user actions:
    C:\workflow\human\run-human.ps1

    STEP 4 - Query CloudTrail from bastion host
    SSH to bastion, then run: ./query-cloudtrail.sh
    "@
    $readme | Out-File "C:\workflow\README.txt"
    </powershell>
  EOF

  tags = {
    Name    = "tiered-identity-windows"
    Purpose = "OpenClaw execution environment simulation"
  }
}

# -------------------
# Bastion Host - Amazon Linux 2023
# Public subnet - SSH from your IP only
# CloudTrail reader role via instance profile
# Single controlled entry point and observation point
# -------------------

data "aws_ami" "bastion" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.bastion.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion.id]
  associate_public_ip_address = true
  key_name                    = data.aws_key_pair.bastion.key_name
  iam_instance_profile        = aws_iam_instance_profile.cloudtrail_reader.name

  user_data = <<-EOF
    #!/bin/bash
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install FreeRDP for Windows instance access
    sudo yum install -y freerdp

    # Create CloudTrail query script
    cat > /home/ec2-user/query-cloudtrail.sh << 'SCRIPT'
    #!/bin/bash
    echo ""
    echo "=== ListUsers events by principal ==="
    echo "Same action. Same instance. Two identities."
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=EventName,AttributeValue=ListUsers \
      --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
      --output table

    echo ""
    echo "=== Denied actions - least privilege enforced ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=EventName,AttributeValue=StartLogging \
      --query 'Events[*].{Time:EventTime,User:Username,Event:EventName,Error:CloudTrailEvent}' \
      --output table

    echo ""
    echo "=== All automation role activity ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=Username,AttributeValue=tiered-identity-automation-role \
      --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
      --output table

    echo ""
    echo "=== All human user activity ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=Username,AttributeValue=tiered-identity-human-user \
      --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
      --output table
    SCRIPT

    chmod +x /home/ec2-user/query-cloudtrail.sh
    chown ec2-user:ec2-user /home/ec2-user/query-cloudtrail.sh

    # README for bastion session
    cat > /home/ec2-user/README.txt << 'README'
    CLOUDTRAIL OBSERVATION POINT
    =============================

    After running proof of concept scripts on Windows instance:

    Query CloudTrail:
    ./query-cloudtrail.sh

    RDP to Windows instance:
    xfreerdp /u:Administrator /v:WINDOWS_PRIVATE_IP /port:3389
    README

    chown ec2-user:ec2-user /home/ec2-user/README.txt
  EOF

  tags = {
    Name    = "tiered-identity-bastion"
    Purpose = "Controlled access and CloudTrail observation point"
  }
}
