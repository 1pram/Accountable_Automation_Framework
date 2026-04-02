# Accountable Automation Framework

### Project overview

This project examines the security implications of AI agents that operate under the user's authority. Using OpenClaw as a case study, it demonstrates how delegated automation can collapse identity boundaries when agents inherit and reuse  user credentials. In this condition, human and automation actions become indistinguishable in logs, weakening the blast attribution and non-repudiation while expanding the blast radius of compromise.

The project develops a threat model to expose this "dual identity" problem by diagramming the failure mode at its root cause and enumerating its overall impact. To adddress this, a reference architecture demonstrates the corrected design in a controlled environment. It restores accountability through separate service identities, scoped access delegation, and principled enforcement of least privilege. 

This is not a reaction to a single vulnerability. It's a response to a pattern. One where keeping up with the speed of adoption has led to overlooking the governance frameworks designed to contain it. 

### What this demonstrates

How least privilege strengthens attribution and contains the blast ardius when applied at the identity layer.
The agent performs is intended functions fully within scoped permissions. No privilege bloat. No blank checks required.
The tried and true operational friction of the tiered identity is not only relevant today, it restores accountability to autonomous workflows.

### Connection to previous work

This architecture extends my [Secure Cloud Network](https://github.com/1pram/Secure_Cloud_Network.git) project as a foundation. Much like that infrastructure, it features a ulti-layered appraoch to least privilege though segmentation, subnets (public and private), and controlled ingress. this project adds an identity layer, separating human authority from delegated automation at the architectural level.

### Repository Structure
```
accountable_automation_framework/
├── README.md
├── main.tf                    # Provider configuration and default tags
├── variables.tf               # Input variables
├── terraform.tfvars.example   # Safe template — never commit terraform.tfvars
├── network.tf                 # VPC, subnets, security groups, VPC endpoints
├── iam.tf                     # Three principals: human user, automation role,
│                              # CloudTrail reader — each scoped to purpose
├── storage.tf                 # CloudTrail logs bucket and workflow bucket
├── secrets.tf                 # AWS Secrets Manager — replaces plaintext 
│                              # credential storage
├── cloudtrail.tf              # Tamper-proof audit trail
├── instances.tf               # Windows Server 2022 and bastion host
├── outputs.tf                 # Post-apply configuration values
├── .gitignore                 # Protects sensitive files from version control
└── docs/
    ├── architecture.md        # Full architecture walkthrough
    ├── threat-model.md        # Formal OWASP threat model documentation
    ├── decisions-tradeoffs.md # Key decisions and honest trade-offs
    ├── proof-of-concept.md    # Step-by-step demonstration guide
    └── diagrams/
        ├── dual-identity-dataflow.png    # Before — detection surface, 
        │                                 # absent boundary
        └── tiered-identity-dataflow.png  # After — trust boundary restored,
                                          # logs attribute actions to 
                                          # their actual authors
```
### Prerequisites

- Terraform >= 1.0
- VSCode terminal or the AWS CLI configured with sufficient permissions to create IAM, EC2, S3, CloudTrail, and Secrets Manager  
  resources.
- An existing key pair for the bastion SSH access.
- Your public IP address for bastion ingress scoping.

### Cost considerations

- EC2 instances: t3.medium (Windows) and t3.micro (bastion running ubuntu)
- VPC endpoint replace NAT gateway. Private subnet never  touches the Internet.
- S3 Gateway endpoints for S3 access is free
- Secrets Manager Interface endpoint:  less than $0.01/hour
- CloudTrail:  first trail in each region is free
- Teardown after demonstration to avoid ongoing charges: terraform destroy

### Closing notes

The Accountable Automation Framework is the third project in this series examining security across different infrastructure layers. The Secure Cloud Network addressed the network and resource layer through defense in depth. The Secure File Portal addressed enforcing the infrastructure layer to enable the system to fail closed in the event of an application layer compromise. This project addresses the identity layer, specifically the condition that emerges when automation inherits human authority without declared boundaries.


For a deeper dive:
The threat model, click here
The complete write-up/related article, click here 

###** Part two**
Coming soon
OpenClaw agent deployment video featuring: CloudTrail log file validation, secret rotation, and full workflow demonstration.

