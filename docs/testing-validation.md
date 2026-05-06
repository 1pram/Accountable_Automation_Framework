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

Expected — human user identity:

```
{
    "UserId": "AIDAXXXXXXXXXX",
    "Account": "YOUR_ACCOUNT_ID",
    "Arn": "arn:aws:iam::YOUR_ACCOUNT_ID:user/aaf-human-user"
}
```


ests collectively verify the framework makes identity boundaries legible, enforces them architecturally, and produces an audit trail that knows the difference between a human action and an automated one.
