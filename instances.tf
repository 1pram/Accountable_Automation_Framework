# bastion host (Latest Amazon Linux 2023 AMI)
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# OpenClaw execution environment (Latest Windows Server 2022 Full Base AMI — )
data "aws_ssm_parameter" "windows_2022" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# Bastion host (Public subnet, SSH from admin IP only)
# Carries CloudTrail reader role via instance profile
# Single controlled entry point and observation point
resource "aws_instance" "bastion" {
  ami                         = data.aws_ssm_parameter.al2023.value
  instance_type               = "t2.micro"
  subnet_id                   = aws_subnet.public_bastion.id
  associate_public_ip_address = true
  key_name                    = var.key_pair_name
 vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile        = aws_iam_instance_profile.bastion_profile.name

  user_data = <<-EOF
    #!/bin/bash
    # Install AWS CLI
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install

    # Install FreeRDP for Windows instance access
    sudo yum install -y freerdp

    # CloudTrail query script — retrieves attribution evidence
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
    echo "=== Denied actions — least privilege enforced ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=EventName,AttributeValue=StartLogging \
      --query 'Events[*].{Time:EventTime,User:Username,Event:EventName}' \
      --output table

    echo ""
    echo "=== All automation role activity ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=Username,AttributeValue=AutomationRole \
      --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
      --output table

    echo ""
    echo "=== All human user activity ==="
    echo ""
    aws cloudtrail lookup-events \
      --lookup-attributes AttributeKey=Username,AttributeValue=aaf-human-user \
      --query 'Events[*].{Time:EventTime,Event:EventName,User:Username}' \
      --output table
    SCRIPT

    chmod +x /home/ec2-user/query-cloudtrail.sh
    chown ec2-user:ec2-user /home/ec2-user/query-cloudtrail.sh
  EOF

  tags = {
    Name    = "aaf-bastion"
    Project = "AAF"
  }
}

# Windows Server 2022 (Private subnet, RDP via bastion only)
# Automation role via instance profile (default, no profile flag needed)
# Human user via named CLI profile (explicit, --profile human-user)
# EBS root volume scoped to OS only (credentials stored in Secrets Manager)
resource "aws_instance" "windows" {
  ami                         = data.aws_ssm_parameter.windows_2022.value
  instance_type               = "t3.medium"
  subnet_id                   = aws_subnet.private_windows.id
  associate_public_ip_address = false
  key_name                    = var.key_pair_name
vpc_security_group_ids = [aws_security_group.windows_instance.id]
  iam_instance_profile        = aws_iam_instance_profile.automation_profile.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true

    tags = {
      Name    = "aaf-windows-os"
      Purpose = "OperatingSystemOnly"
      Project = "AAF"
    }
  }

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

    # Automation role script — runs as instance profile by default
    @"
    # Automation role actions
    # No profile flag — instance profile provides credentials automatically
    Write-Host "=== Automation role (instance profile) ==="

    Write-Host "1. ListUsers — permitted"
    aws iam list-users

    Write-Host "2. Write to automation prefix — permitted"
    "automation log $(Get-Date)" | Out-File C:\workflow\automation\log.txt
   aws s3 cp C:\workflow\automation\log.txt s3://${aws_s3_bucket.workflow.id}/automation/

    Write-Host "3. GetSecretValue — permitted"
    aws secretsmanager get-secret-value --secret-id openclaw/automation/ai-service-api-key

    Write-Host "4. StartLogging — explicitly denied"
    aws cloudtrail start-logging --name aaf-trail

    Write-Host "5. CreateSnapshot — explicitly denied"
    aws ec2 create-snapshot --volume-id (aws ec2 describe-volumes --query 'Volumes[0].VolumeId' --output text)
    "@ | Out-File "C:\workflow\automation\run-automation.ps1"

    # Human user script — uses named profile explicitly
    @"
    # Human user actions
    # Configure first: aws configure --profile human-user
    Write-Host "=== Human user (named profile) ==="

    Write-Host "1. ListUsers — permitted"
    aws iam list-users --profile human-user

    Write-Host "2. Write to human prefix — permitted"
    "human file $(Get-Date)" | Out-File C:\workflow\human\file.txt
   aws s3 cp C:\workflow\human\file.txt s3://${aws_s3_bucket.workflow.id}/human/ --profile human-user
   
    Write-Host "3. RebootInstances — permitted"
    aws ec2 reboot-instances --instance-ids (Invoke-RestMethod -Uri http://169.254.169.254/latest/meta-data/instance-id) --profile human-user
    "@ | Out-File "C:\workflow\human\run-human.ps1"

    # README for RDP session
    @"
    ACCOUNTABLE AUTOMATION FRAMEWORK — Proof of Concept
    =====================================================
    STEP 1 — Configure human user profile:
      aws configure --profile human-user
      (Access key and secret key from Terraform outputs)

    STEP 2 — Run automation role actions:
      C:\workflow\automation\run-automation.ps1

    STEP 3 — Run human user actions:
      C:\workflow\human\run-human.ps1

    STEP 4 — Query CloudTrail from bastion:
      SSH to bastion, then run: ./query-cloudtrail.sh
    "@ | Out-File "C:\workflow\README.txt"
    </powershell>
  EOF

  tags = {
    Name    = "aaf-windows"
    Project = "AAF"
  }
}
