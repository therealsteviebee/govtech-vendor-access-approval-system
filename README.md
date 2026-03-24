## Business Problem

Organizations frequently grant external vendors temporary access to internal systems (e.g., SharePoint, project portals, document repositories).

Without structured workflows:
- access requests are inconsistent
- approvals are not properly tracked
- audit trails are incomplete
- access may persist beyond intended timeframes

This system simulates a controlled, auditable workflow for managing vendor access requests in regulated environments.

# Vendor Access Governance & Approval & Audit System (GovTech Demo)

This project simulates a real-world vendor or contractor access request workflow for regulated organizations and public-sector environments. A requester submits an access request, the system validates the payload, creates a Jira Service Management approval ticket, sends a Slack notification to the approver or operations channel, and writes an audit record to Azure Table Storage.

## Key Features

- Automated Jira ticket creation for approval workflows  
- Slack-based notification for visibility and follow-up  
- Azure Table Storage audit logging  
- Structured request validation  
- Extensible architecture for compliance and governance use cases

## Solution Overview

This demo is designed to showcase:

- approval-driven workflow automation
- access governance and compliance concepts
- SaaS integrations across Jira, Slack, and Azure
- event-driven architecture
- auditability and traceability for external access requests

## Architecture

- **Frontend:** simple HTML vendor access request form
- **Backend:** Azure Function (PowerShell, HTTP trigger)
- **Workflow Engine:** Jira Service Management
- **Notifications:** Slack API
- **Audit Log:** Azure Table Storage
- **Documentation:** Markdown workflow notes and architecture diagram

## End-to-End Flow

1. Vendor or employee submits an access request
2. Azure Function validates and parses the payload
3. Azure Function creates a Jira approval ticket
4. Azure Function writes an audit record to Azure Table Storage
5. Azure Function posts a Slack notification to the approver or operations channel
6. Team reviews, approves, or denies the request in Jira

## Repository Structure

```text
govtech-vendor-access-approval-system/
├── README.md
├── .gitignore
├── architecture/
│   └── vendor-access-architecture.svg
├── docs/
│   └── workflow.md
├── samples/
│   └── sample-request.json
└── src/
    └── azure-function/
        ├── function.json
        ├── run.ps1
        ├── profile.ps1
        └── vendor-access-form.html
```

## Configuration Required

Set these values in your Azure Function App settings before testing:

- `JIRA_BASE_URL`
- `JIRA_EMAIL`
- `JIRA_API_TOKEN`
- `JIRA_PROJECT_KEY`
- `JIRA_ISSUE_TYPE`
- `SLACK_BOT_TOKEN`
- `SLACK_CHANNEL_ID`
- `AZURE_STORAGE_CONNECTION_STRING`
- `AUDIT_TABLE_NAME`

## Notes

- This repo uses placeholder values and is meant to be safe to publish
- Do **not** commit real secrets to GitHub
- The HTML form can be hosted anywhere or used as a local/static demo
- The audit record is intentionally simple and portfolio-friendly

## Interview Talking Point

> I built a vendor access approval and audit system using Azure Functions, PowerShell, Jira Service Management, Slack, and Azure Table Storage. It simulates how regulated organizations manage external access requests with approvals, notifications, and audit logging.
