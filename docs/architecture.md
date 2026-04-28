# Architecture

The Accountable Automation Framework is an identity-first infrastructure that separates human authority from delegated automation. It extends the Secure Cloud Network project by adding an identity layer on top of an existing least privilege foundation.

### 1. Service Inventory

This project uses the following AWS services:

- **Amazon VPC**: Network boundary housing public and private subnets with controlled ingress.
- **Amazon EC2 (Bastion Host)**: Single controlled entry point into the private subnet via SSH.
- **Amazon EC2 (Workflow Host)**: Windows Server 2022 instance carrying the automation role via instance profile.
- **Amazon EBS**: Root volume for the Windows instance, operating system only, not for credential storage.
- **AWS IAM**: Three scoped principals, human user, automation role with permissions boundary, CloudTrail reader role.
- **AWS Secrets Manager**: Encrypted credential storage for the automation role. It replaces plaintext EBS storage.
- **AWS CloudTrail**: Multi-region audit trail logging all management events and attributing them to specific principals.
- **Amazon S3 (CloudTrail logs bucket)**: Tamper-proof log storage, used for CloudTrail service access only.
- **Amazon S3 (Workflow bucket)**: Shared storage scoped by prefix, human/ for the human user, automation/ for the automation role.
- **VPC Endpoints**: S3 Gateway endpoint, Secrets Manager interface endpoint, CloudTrail interface endpoint. The private subnet never touches the public internet.

### 2. Network Design

### VPC and Subnets

The VPC uses a two-subnet model:

- **Public subnet** — hosts the bastion host, reachable from the internet via the internet gateway
- **Private subnet** — hosts the Windows workflow instance, no direct internet route

The private subnet reaches AWS services exclusively through VPC endpoints. No NAT gateway. No public internet exposure.

### Internet Gateway

The internet gateway serves one purpose — inbound SSH from the administrator's IP to the bastion host. The private subnet has no route to the internet gateway.

### Security Groups

- **Bastion SG** — allows SSH on port 22 from the administrator's IP only
- **Windows SG** — allows RDP on port 3389 from the bastion security group only
- **Endpoints SG** — allows HTTPS on port 443 from the private subnet CIDR only

### VPC Endpoints

Three endpoints eliminate the need for a NAT gateway:

- **S3 Gateway endpoint** — free, routes all S3 traffic from the private subnet through the AWS network
- **Secrets Manager interface endpoint** — private encrypted credential retrieval
- **CloudTrail interface endpoint** — private audit trail delivery

### 3. Identity Model

This is the core of the framework. Two IAM principals are declared, scoped, and kept separate.

### Human IAM User

- Permanent identity with long-term credentials
- Configured as a named CLI profile on the Windows instance
- Invoked explicitly with `--profile human-user`
- Permitted actions: ListUsers, write to human/ S3 prefix, reboot the workflow instance

### Automation IAM Role

- Assumable identity attached to the Windows instance via instance profile
- Default identity for all CLI commands run without a profile flag
- Governed by a permissions boundary that cannot be overridden
- Permitted actions: ListUsers, write to automation/ S3 prefix, GetSecretValue from Secrets Manager
- Explicitly denied: CloudTrail modification, EBS snapshot creation

### Permissions Boundary

The automation role carries a permissions boundary defining the absolute ceiling of what it can ever do — regardless of what policies are attached later. Explicit denies in the boundary override any attached policy. This makes least privilege durable, not just momentary.

### CloudTrail Reader Role

- Attached to the bastion host via instance profile
- Read-only access to CloudTrail events and the logs S3 bucket
- Cannot modify the trail or write to the logs bucket
- Used to query attribution evidence from the bastion

### 4. Credential Storage

The automation role retrieves its AI service API key from AWS Secrets Manager through the Secrets Manager VPC endpoint. The key is stored encrypted. Every retrieval is logged by CloudTrail under the automation role identity with the exact secret ARN.

This replaces the plaintext credential storage on an unmanaged EBS volume that the dual identity threat model identified as an information disclosure vulnerability.

### 5. Audit Trail

CloudTrail is configured as a multi-region trail logging all management events. It captures IAM AssumeRole calls through `include_global_service_events = true` — meaning the moment the automation role is assumed by the EC2 instance is itself a logged event.

The logs bucket is governed by a bucket policy that permits only the CloudTrail service to write. Neither the human user nor the automation role can modify or disable the trail. Log file validation is deferred to part two.

### 6. Attribution Model

Every action produces a CloudTrail entry attributed to a specific principal:

- Human user actions — logged under `aaf-human-user`
- Automation role actions — logged under `AutomationRole`
- CloudTrail reader queries — logged under `BastionCloudTrailReaderRole`

Same instance. Same IP. Three distinct identities in the log. The audit trail knows the difference.

### 7. Design Decisions and Trade-offs

**NAT gateway replaced by VPC endpoints** — keeps the private subnet fully isolated from the public internet while maintaining full AWS service connectivity. Interface endpoints carry a small hourly cost; the S3 Gateway endpoint is free.

**EBS scoped to OS only** — EBS remains as the Windows root volume because Windows EC2 instances boot from EBS. Credential storage moved to Secrets Manager. The EBS volume tag `Purpose: OperatingSystemOnly` makes this boundary visible in the infrastructure.

**Lambda excluded** — Lambda was considered for the automation execution environment but ruled out. OpenClaw's persistent nature requires stateful execution across workflows. Lambda's stateless, ephemeral design would produce the equivalent of short and long-term memory loss for the agent.

**Human user credentials on the instance** — the human IAM user's access key is stored in the AWS CLI credentials file on the Windows instance. This is a deliberate design choice — configuring the profile manually is itself a mindfulness trigger, requiring a conscious act to invoke the human identity rather than inheriting it by default. In production, short-term credentials through AWS IAM Identity Center would replace long-term access keys entirely. The named profile pattern would remain — only the credential source changes.

**Versioned S3 buckets require manual cleanup before destroy** — versioning protects the audit trail during operation but requires explicit version deletion before `terraform destroy`. A lifecycle policy would automate this in production.

**Log file validation deferred to part two** — full non-repudiation validation belongs in the live agent demo where real agent activity generates the complete audit trail.

**CloudWatch deferred to part two** — CloudTrail handles attribution in this proof of concept. CloudWatch behavioral monitoring, anomaly detection on denied actions, and Secrets Manager access frequency alarms belong in part two alongside the live agent.

### 8. Summary

`architecture.md` captures:

- What each component does and why it exists
- How the network, identity, and credential layers work together
- Which constraints are intentional and what they protect against
- How the design makes attribution legible by default
