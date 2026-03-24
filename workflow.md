# Workflow Breakdown

## Step 1: Request Submission
A requester submits a vendor or contractor access request with:
- requester name
- requester email
- vendor name
- vendor email
- target system
- access reason
- start date
- end date
- approver name
- approver email

## Step 2: HTTP Trigger Processing
The Azure Function receives the payload and validates required fields.

## Step 3: Jira Approval Ticket Creation
The function builds a Jira issue payload and creates an approval ticket in Jira Service Management.

## Step 4: Audit Logging
The function writes an audit record to Azure Table Storage with key request details and current status.

## Step 5: Slack Notification
After the Jira issue is created, the function posts a Slack notification to the designated channel for visibility and follow-up.

## Step 6: Review and Decision
The request is reviewed in Jira and moved through workflow states such as:
- Submitted
- Pending Approval
- Approved
- Denied
- Expired

## Suggested Future Enhancements
- automatic expiration reminders
- approval reminders for stale requests
- role-based routing by requested system
- email notifications to requester and approver
- reporting dashboard for approvals and denials
