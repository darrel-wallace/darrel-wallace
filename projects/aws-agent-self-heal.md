# Project Case Study: Automated Monitoring & Self-Healing for AWS Agents

## Executive Summary

* **The Problem:** Critical AWS agent services (CloudWatch, SSM) on a fleet of Windows EC2 instances would silently fail, halting all log/metric collection and breaking remote management capabilities. This was a critical visibility and compliance gap.
* **The Solution:** I engineered an event-driven, self-healing system using 100% native AWS services. The system automatically detects a service failure, treats missing data as a breach, and triggers an SSM Run Command to restart the failed service, restoring full functionality within minutes without human intervention.
* **The Outcome:** This solution created a resilient, "hands-off" system that guarantees data collection and instance manageability. It was built as Infrastructure as Code (IaC) for consistent, repeatable deployment across any AWS account.

---

## Key Technologies Used

* **AWS CloudFormation (IaC):** To define and deploy the entire solution as code.
* **AWS Lambda (Python):** To run the serverless remediation logic.
* **Amazon CloudWatch:** Used for custom metrics (`procstat`) and alarms.
* **Amazon SNS:** To decouple alarms from the Lambda function.
* **AWS Systems Manager (SSM):** To execute the remediation (`AWS-RunPowerShellScript`) on the target instance.
* **Advanced Troubleshooting:** Diagnosed and resolved complex "red herring" issues involving IAM policies, IMDSv2, and conflicting agent configurations.

---

## Solution Architecture

Leveraging Infrastructure as Code (IaC) principles was a key objective. I chose AWS CloudFormation to define and deploy the necessary resources consistently across multiple instances and accounts. The design follows a standard event-driven pattern:

* **CloudWatch Agent Configuration:** Configured the agent to report its own process count (`pid_count`) and the SSM agent's process count as custom metrics using the `procstat` plugin.
* **CloudWatch Alarms:** Alarms were set up to monitor these `pid_count` metrics.
* **SNS Topic:** Alarms were configured to publish notifications to an SNS topic upon entering the `ALARM` state.
* **Lambda Function:** A Python Lambda function subscribed to the SNS topic. Its role was to parse the alarm message, identify the affected instance and service, and trigger a remediation action.
* **SSM Run Command:** The Lambda function would execute the `AWS-RunPowerShellScript` document via SSM Run Command on the target instance to restart the appropriate service.

This design provided decoupling between detection and remediation and allowed for easy extension.

---

## Implementation and Troubleshooting Challenges

Deploying and refining this solution involved several key troubleshooting steps:

* **Alarm Threshold Mismatch:** Initial testing revealed that the CloudWatch Agent runs two processes (parent/supervisor and child/worker) for resiliency. The alarm threshold for its `pid_count` metric had to be adjusted from `< 1` to `< 2` to correctly detect partial or total failure. The SSM Agent, running as a single process, correctly used the `< 1` threshold.
* **Handling Missing Data:** Stopping the CloudWatch Agent service caused the alarm to enter an `INSUFFICIENT_DATA` state instead of `ALARM`, as the agent stopped sending metrics altogether. The fix was to configure the alarm's "Treat missing data" setting to "breaching," ensuring that a loss of signal was treated as a failure.
* **Adapting CloudFormation:** Initial template design included creating new IAM roles and SNS topics. Due to existing infrastructure and permissions constraints, the template was refactored to:
    * Accept the ARN of a pre-existing IAM role for the Lambda function via a parameter.
    * Accept the ARN of a pre-existing SNS topic via a parameter.
    * Later, these parameters were updated to use `Default` values, streamlining deployment by pre-populating the ARNs specific to each AWS account while still allowing overrides.
* **CloudFormation Update Issues:** When refining alarm configurations (specifically changing immutable properties like `Namespace` and `Dimensions`), CloudFormation sometimes failed to replace the existing alarms correctly, even though the stack update reported success. Manually deleting the problematic alarms and re-deploying the stack (or deleting and recreating the stack) was necessary to force CloudFormation to reconcile the deployed state with the template.
* **Persistent Alarm State & The Red Herrings:** The most challenging issue involved several instances where alarms entered the `ALARM` state immediately after deployment, despite the agent service running and the CloudFormation template/agent config appearing correct. This led down several incorrect paths:
    * **IAM Deny Policies:** Investigated explicit denies or permissions boundaries, but none were found blocking `cloudwatch:PutMetricData`.
    * **Network/Endpoint Issues:** Considered potential blocks to AWS endpoints, especially given the instances were in a specific, controlled AWS region, but this was disproven when other instances in the same region worked fine.
    * **IMDSv2 Conflicts:** Verified that both working and non-working instances required IMDSv2. Manual PowerShell tests confirmed that all instances could successfully retrieve credentials via IMDSv2, ruling out local firewalls or proxy issues blocking the metadata service itself.
    * **Agent Version/Proxy:** Confirmed all instances used the same agent version and had no relevant proxy settings configured in the agent's `common-config.toml`.
* **The Breakthrough - Conflicting Configuration:** The key insight came from comparing the successful deployments in one account with the failing ones in another. While the primary `amazon-cloudwatch-agent.json` file (managed via CloudFormation deployment/user data) was identical, the failing instances had an additional, older, conflicting agent configuration file present in a default location. The agent was likely attempting to load or merge both files, causing the `procstat` metric collection to fail silently before log collection even started (explaining differences seen in agent logs).

---

## Final Solution and Outcome

The final, successful solution involved:

* Using the refined CloudFormation template with default parameters for the account-specific IAM role and SNS topic ARNs.
* Ensuring the `TreatMissingData: 'breaching'` setting was included in the alarm definitions within the template.
* Crucially, adding a step to the instance deployment/setup process to explicitly remove any pre-existing or default CloudWatch agent configuration files before applying the intended `amazon-cloudwatch-agent.json` configuration.
* Restarting the `AmazonCloudWatchAgent` service after configuration.

This resulted in a stable, automated system where:

* CloudWatch and SSM agent failures are detected by CloudWatch Alarms.
* Notifications are sent via SNS.
* A Lambda function triggers an SSM Run Command to restart the failed service.
* The system correctly handles missing metric data.
* Deployment is managed consistently via CloudFormation.

---

## Key Learnings

* **Treat Missing Data Appropriately:** When monitoring agent heartbeats or process counts, configure alarms to treat missing data as a breach (`breaching`).
* **Verify Agent Behavior:** Understand the expected process count for services like the CloudWatch Agent (which runs two processes).
* **Idempotency is Key:** Ensure deployment processes clean up or overwrite previous configurations to avoid conflicts, especially with agent software that might load multiple config files.
* **Troubleshooting Steps:** When basic configuration checks fail, systematically investigate IAM (including boundaries), network paths (endpoints, proxies), instance metadata access (IMDS), agent versions, and finally, conflicting local configurations. Manual testing from the instance (e..g., PowerShell IMDS checks) is vital.
* **Infrastructure as Code Benefits:** While troubleshooting was complex, having the core infrastructure defined in CloudFormation made iterating on fixes (like adding `TreatMissingData`) much more manageable across multiple instances.
