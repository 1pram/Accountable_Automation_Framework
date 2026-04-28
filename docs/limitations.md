# Known Limitations

The Accountable Automation Framework is a focused identity and observability project, not a full production deployment. This document describes what it does not cover to set realistic expectations going forward.

### 1. No Live Agent

The proof of concept simulates automation activity through CLI scripts rather than a running OpenClaw agent. The automation role is assumed by the EC2 instance profile and invoked manually through PowerShell scripts.

In a live deployment, the agent would assume the automation role directly through the same instance profile mechanism. The attribution architecture is identical in both cases. The CloudTrail output does not change based on whether a human or an agent triggers the role assumption. Part two addresses the live agent deployment.

### 2. Long-Term Human User Credentials on the Instance

The human IAM user's access key is stored in the AWS CLI credentials file on the Windows instance for demonstration purposes. This is a known trade-off for the proof of concept.

In production, short-term credentials through AWS IAM Identity Center would replace long-term access keys entirely. The named profile pattern would remain — only the credential source changes.

### 3. No Secret Rotation

The AI service API key in Secrets Manager is static for this proof of concept. Automatic secret rotation is deferred to part two alongside the live agent deployment.

The rotation mechanism is noted as a commented placeholder in `secrets.tf`.

### 4. No Log File Validation

CloudTrail log file validation which produces a digest file allowing verification that no logs were modified or deleted after delivery is disabled in this proof of concept.

This is a deliberate scope decision. Log file validation belongs in part two where the full non-repudiation story plays out with real agent activity and a complete audit trail lifecycle.

### 5. Manual S3 Bucket Cleanup Before Destroy

Versioned S3 buckets require explicit version and delete marker deletion before `terraform destroy` succeeds. This is a deliberate trade-off between tamper-proof audit trail integrity during operation and teardown simplicity in a proof of concept environment.

A lifecycle policy would automate this in production. See `troubleshooting.md` for the manual cleanup procedure.

### 6. Single Region Deployment

The current design deploys to a single AWS region. CloudTrail is configured as a multi-region trail to capture API calls regardless of region, but the infrastructure itself is region-specific.

Multi-region failover, cross-region replication, and data residency considerations are out of scope for this project.

### 8. Windows-Specific Architecture

The architecture is designed around a Windows Server 2022 EC2 instance as the OpenClaw execution environment. This reflects the real-world deployment surface documented in the dual identity threat model.

The identity and attribution mechanisms: IAM roles, instance profiles, CloudTrail, Secrets Manager are platform-agnostic. The Windows-specific elements are the RDP access pattern, the PowerShell proof of concept scripts, and the EBS root volume requirement.
