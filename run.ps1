using namespace System.Net

param($Request, $TriggerMetadata)

$ErrorActionPreference = "Stop"

function Get-RequiredSetting {
    param([string]$Name)

    $value = [Environment]::GetEnvironmentVariable($Name)
    if ([string]::IsNullOrWhiteSpace($value)) {
        throw "Missing required application setting: $Name"
    }
    return $value
}

function Write-JsonResponse {
    param(
        [int]$StatusCode,
        [object]$BodyObject
    )

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
        StatusCode = $StatusCode
        Headers    = @{ "Content-Type" = "application/json" }
        Body       = ($BodyObject | ConvertTo-Json -Depth 10)
    })
}

function New-AuditRowKey {
    return ([guid]::NewGuid().ToString())
}

try {
    $body = $Request.Body

    if ($body -is [string]) {
        $body = $body | ConvertFrom-Json
    }

    if (-not $body) {
        throw "Request body is empty."
    }

    $requiredFields = @(
        "requesterName",
        "requesterEmail",
        "vendorName",
        "vendorEmail",
        "targetSystem",
        "accessReason",
        "startDate",
        "endDate",
        "approverName",
        "approverEmail"
    )

    foreach ($field in $requiredFields) {
        if ([string]::IsNullOrWhiteSpace([string]$body.$field)) {
            throw "Missing required field: $field"
        }
    }

    $jiraBaseUrl   = Get-RequiredSetting -Name "JIRA_BASE_URL"
    $jiraEmail     = Get-RequiredSetting -Name "JIRA_EMAIL"
    $jiraApiToken  = Get-RequiredSetting -Name "JIRA_API_TOKEN"
    $jiraProject   = Get-RequiredSetting -Name "JIRA_PROJECT_KEY"
    $jiraIssueType = Get-RequiredSetting -Name "JIRA_ISSUE_TYPE"
    $slackToken    = Get-RequiredSetting -Name "SLACK_BOT_TOKEN"
    $slackChannel  = Get-RequiredSetting -Name "SLACK_CHANNEL_ID"
    $storageConn   = Get-RequiredSetting -Name "AZURE_STORAGE_CONNECTION_STRING"
    $auditTable    = Get-RequiredSetting -Name "AUDIT_TABLE_NAME"

    $summary = "[Vendor Access] $($body.vendorName) -> $($body.targetSystem)"

    $descriptionLines = @(
        "Requester Name: $($body.requesterName)",
        "Requester Email: $($body.requesterEmail)",
        "Vendor Name: $($body.vendorName)",
        "Vendor Email: $($body.vendorEmail)",
        "Target System: $($body.targetSystem)",
        "Access Reason: $($body.accessReason)",
        "Start Date: $($body.startDate)",
        "End Date: $($body.endDate)",
        "Approver Name: $($body.approverName)",
        "Approver Email: $($body.approverEmail)"
    )

    $jiraPayload = @{
        fields = @{
            project     = @{ key = $jiraProject }
            summary     = $summary
            description = ($descriptionLines -join "`n")
            issuetype   = @{ name = $jiraIssueType }
        }
    } | ConvertTo-Json -Depth 10

    $jiraAuthBytes = [System.Text.Encoding]::UTF8.GetBytes("$jiraEmail`:$jiraApiToken")
    $jiraAuthValue = [Convert]::ToBase64String($jiraAuthBytes)

    $jiraHeaders = @{
        "Authorization" = "Basic $jiraAuthValue"
        "Accept"        = "application/json"
        "Content-Type"  = "application/json"
    }

    $jiraResponse = Invoke-RestMethod -Method Post `
        -Uri "$jiraBaseUrl/rest/api/3/issue" `
        -Headers $jiraHeaders `
        -Body $jiraPayload

    if ([string]::IsNullOrWhiteSpace([string]$jiraResponse.key)) {
        throw "Jira approval ticket was not created successfully."
    }

    try {
        Import-Module Az.Storage -ErrorAction Stop | Out-Null
        $ctx = New-AzStorageContext -ConnectionString $storageConn
        $tableClient = (Get-AzStorageTable -Name $auditTable -Context $ctx -ErrorAction Stop).CloudTable

        $partitionKey = "VendorAccess"
        $rowKey = New-AuditRowKey
        $timestampUtc = [DateTime]::UtcNow.ToString("o")

        $entity = New-Object Microsoft.Azure.Cosmos.Table.DynamicTableEntity($partitionKey, $rowKey)
        $entity.Properties.Add("RequesterName", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.requesterName))
        $entity.Properties.Add("RequesterEmail", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.requesterEmail))
        $entity.Properties.Add("VendorName", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.vendorName))
        $entity.Properties.Add("VendorEmail", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.vendorEmail))
        $entity.Properties.Add("TargetSystem", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.targetSystem))
        $entity.Properties.Add("ApproverName", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.approverName))
        $entity.Properties.Add("ApproverEmail", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.approverEmail))
        $entity.Properties.Add("StartDate", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.startDate))
        $entity.Properties.Add("EndDate", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$body.endDate))
        $entity.Properties.Add("JiraKey", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString([string]$jiraResponse.key))
        $entity.Properties.Add("Status", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString("Submitted"))
        $entity.Properties.Add("LoggedAtUtc", [Microsoft.Azure.Cosmos.Table.EntityProperty]::GeneratePropertyForString($timestampUtc))

        $insertOperation = [Microsoft.Azure.Cosmos.Table.TableOperation]::Insert($entity)
        $null = $tableClient.Execute($insertOperation)
    }
    catch {
        throw "Audit logging failed: $($_.Exception.Message)"
    }

    $slackPayload = @{
        channel = $slackChannel
        text    = "Vendor access request created: *$($jiraResponse.key)* | $($body.vendorName) -> $($body.targetSystem) | Approver: $($body.approverName)"
    }

    $slackHeaders = @{
        "Authorization" = "Bearer $slackToken"
    }

    $slackResponse = Invoke-RestMethod -Method Post `
        -Uri "https://slack.com/api/chat.postMessage" `
        -Headers $slackHeaders `
        -Body $slackPayload

    if (-not $slackResponse.ok) {
        throw "Slack notification failed: $($slackResponse.error)"
    }

    Write-JsonResponse -StatusCode 200 -BodyObject @{
        success     = $true
        message     = "Vendor access request processed successfully."
        jiraKey     = $jiraResponse.key
        jiraId      = $jiraResponse.id
        slackSent   = $true
        auditLogged = $true
    }
}
catch {
    Write-JsonResponse -StatusCode 400 -BodyObject @{
        success = $false
        error   = $_.Exception.Message
    }
}
