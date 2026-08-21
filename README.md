# Step-by-Step Guide to Create an Azure Foundry Instance and Provision LLM Deployments

This guide explains how to create a Microsoft Foundry resource and project, deploy an Anthropic Claude model using Global Standard, apply governance tags, and configure a USD 200 monthly cost alert.

> Azure AI Foundry is now called **Microsoft Foundry**. An "instance" generally consists of a Foundry resource/account containing one or more projects.

## Deploy the complete environment

[![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Frick-ji%2Fstep-by-step-guide-to-create-azure-foundry-instance-and-provision-llm-deployments%2F65c22ef8f243ba7c3f47f9ab21dd10725624cb33%2Finfra%2Fazuredeploy.json)

The button opens an Azure custom deployment and creates:

- A Microsoft Foundry account with project management enabled.
- A Foundry project.
- A Claude **Global Standard** deployment.
- Governance tags on the Foundry account and project.
- A monthly resource-group budget preconfigured to `200`, with actual alerts at 80% and 100% and a forecasted alert at 100%.

Most template values are prepopulated. You must supply:

- `claudeOrganizationName`: the real legal organization accepting Anthropic's Marketplace terms.
- `claudeCountryCode`: the organization's two-letter ISO country code.
- `budgetAlertEmail`: the notification recipient.

Before selecting **Review + create**, verify the model is available in the selected region, the billing currency is USD if `200` is intended to mean USD 200, and the organization information is accurate. Deploying the template submits `modelProviderData` and accepts the Anthropic Marketplace offer. Review [Anthropic's commercial terms](https://www.anthropic.com/legal/commercial-terms) first.

> **Region compatibility:** The template defaults to `eastus2` because Claude Opus 5 version `1` with the `GlobalStandard` SKU is currently supported in East US 2 and Sweden Central, but not Australia East. A Foundry account in `australiaeast` can't host this deployment combination. If Australian regional placement is mandatory, select a model/SKU listed for Australia East instead of overriding this template's location.

The deployment uses public network access and permits API-key authentication to keep the example broadly usable. Production environments should evaluate private endpoints, disabling local authentication, customer-managed keys, least-privilege RBAC, and Azure Policy before deployment.

### Deploy with Azure CLI

The source template is [`infra/main.bicep`](infra/main.bicep). [`infra/azuredeploy.json`](infra/azuredeploy.json) is the compiled ARM template used by the button, and [`infra/main.parameters.json`](infra/main.parameters.json) contains reusable non-sensitive defaults.

```bash
az group create \
  --name rg-foundry-claude-prod \
  --location eastus2

az deployment group create \
  --resource-group rg-foundry-claude-prod \
  --template-file infra/main.bicep \
  --parameters @infra/main.parameters.json \
  --parameters \
    claudeOrganizationName="<legal-organization-name>" \
    claudeCountryCode="<two-letter-country-code>" \
    budgetAlertEmail="<alert-recipient@example.com>"
```

The account name is generated from the subscription and resource-group IDs so that its custom subdomain is stable and globally unique in normal use. Override `foundryName` if your naming policy requires another value.

## 1. Check the prerequisites

You need:

- A paid Azure subscription with an active payment method.
- A billing account in a country or region where Anthropic offers Claude.
- Permission to purchase Azure Marketplace offers.
- **Foundry Account Owner** or **Foundry Owner** to create the Foundry resource.
- **Contributor** or **Owner** on the target resource group.
- **Cost Management Contributor**, **Contributor**, or **Owner** to create the budget.

Claude isn't currently supported on CSP, student, free-trial, startup-credit-only, or sponsored-credit-only subscriptions without active pay-as-you-go billing. Organization policies can also block Azure Marketplace purchases.

## 2. Create a dedicated resource group

A dedicated resource group provides a clean scope for access control, tagging, cost monitoring, and eventual cleanup.

1. Sign in to the [Azure portal](https://portal.azure.com).
2. Search for **Resource groups** and select **Create**.
3. Select the eligible paid subscription.
4. Enter a name such as `rg-foundry-claude-prod`.
5. Select a region supported by Microsoft Foundry and the intended model.
6. Add the governance tags described below.
7. Select **Review + create**, then **Create**.

Keep unrelated resources out of this resource group if its budget is intended to represent only the Foundry workload.

## 3. Apply resource tags

Recommended resource tags include:

| Tag | Example value |
| --- | --- |
| `Service` | `MicrosoftFoundry-Claude` |
| `Environment` | `Production` |
| `CostCenter` | `AI-001` |
| `Owner` | `AI-Platform-Team` |
| `Application` | `ClaudeApplication` |
| `ManagedBy` | `PlatformEngineering` |
| `BudgetLimitUSD` | `200` |
| `DataClassification` | `Internal` |

To apply them:

1. Open the resource group or resource in the Azure portal.
2. Select **Tags** or **Add tags**.
3. Enter each name and value.
4. Select **Save**.

Apply tags to both the resource group and the Foundry resource. Azure resources don't automatically inherit tags from their resource group. Use Azure Policy if tag inheritance or enforcement is required.

Tags are stored as plain text. Never place secrets, keys, personal information, or other sensitive values in them. A `BudgetLimitUSD` tag is only metadata; it doesn't enforce or create a budget.

### Resource tags versus network service tags

The `Service=MicrosoftFoundry-Claude` example is an Azure resource tag used for organization and cost reporting.

An Azure **network service tag** is different: it represents Azure service IP ranges for NSG or Azure Firewall rules. Network service tags aren't attached to a Foundry resource as metadata. Confirm the applicable Foundry or Cognitive Services service tag before changing network rules.

## 4. Create the Foundry resource and project

1. Open [Microsoft Foundry](https://ai.azure.com).
2. Sign in and ensure the **New Foundry** experience is enabled.
3. Open the project selector in the upper-left.
4. Select **Create new project**.
5. Enter a project name, such as `foundry-claude-prod`.
6. Expand **Advanced options**.
7. Select the eligible subscription and `rg-foundry-claude-prod`.
8. Select a supported location.
9. Choose or create a Foundry resource, such as `aif-claude-prod-001`.
10. Select **Create project** and wait for the project overview to load.
11. Open the underlying resource in the Azure portal and apply the tags from step 3.
12. Record the project endpoint shown on the Foundry welcome page.

## 5. Choose a Claude model

1. In Foundry, select **Discover**.
2. Select **Models**.
3. Search for **Claude**.
4. Select the required Sonnet, Haiku, or Opus model.
5. Review its lifecycle status, pricing, token limits, region availability, authentication methods, and hosting option.

Prefer a generally available model for production. Some models have two hosting options:

- **Hosted on Azure:** inference runs on Azure infrastructure end-to-end.
- **Hosted on Anthropic infrastructure:** the model is accessed through Foundry, but inference runs outside Azure.

When both are offered, verify the selection explicitly against the organization's data-residency, compliance, and vendor-risk requirements.

## 6. Accept the Claude Marketplace offer

The first Claude deployment requires an Azure Marketplace subscription.

1. On the model card, select **Deploy** > **Custom settings**.
2. Review the Microsoft and Anthropic Marketplace terms.
3. Select the organization's industry when requested.
4. Confirm that the legal entity, country, and industry information is correct.
5. Select **Agree and Proceed**.

If purchasing is blocked, ask the Azure Marketplace administrator to allow the offer in Private Marketplace, accept its terms, or grant the required purchasing permission.

Claude consumption is billed through **Claude Consumption Units (CCUs)** on the Azure invoice.

## 7. Create a Global Standard deployment

1. Choose the desired model and hosting version.
2. Enter a deployment name, such as `claude-opus-5-global`.
3. Set **Region scope** to **Global**. This corresponds to the `GlobalStandard` deployment SKU.
4. Review the available quota and rate limits.
5. Select **Deploy**.
6. Open **Details** after deployment and confirm:
   - Provisioning state is `Succeeded`.
   - Region scope is `Global`.
   - Model and hosting versions are correct.
   - Deployment name is correct.
7. Send a small test request from the Foundry playground.

### Global Standard data-processing consideration

Global Standard is generally the best starting point for broad availability and pay-per-token usage, but inference data can be processed in any Azure region. Stored data remains in the designated Azure geography.

Don't use Global Standard where policy requires inference processing to stay in a specific country, region, or data zone. Where the chosen model supports it, evaluate **Data Zone Standard** instead.

## 8. Retrieve the Foundry and Claude API endpoints

The Foundry project endpoint and Claude inference endpoint serve different APIs:

```text
Foundry project endpoint:
https://<foundry-resource-name>.services.ai.azure.com/api/projects/<project-name>

Claude SDK base URL:
https://<foundry-resource-name>.services.ai.azure.com/anthropic

Claude Messages API target URI:
https://<foundry-resource-name>.services.ai.azure.com/anthropic/v1/messages
```

Use the **Foundry project endpoint** with the Foundry SDK, agents, evaluations, project files, tools, and project configuration. Use the provider-specific **Claude endpoint** with the Anthropic SDK or Claude Messages REST API when calling the deployed LLM.

The Claude request's `model` value must be the **deployment name**, not necessarily the catalog model ID. This repository's defaults use `claude-opus-5-global`.

### Retrieve them in the portal

1. Sign in to [Microsoft Foundry](https://ai.azure.com) and open the project.
2. Copy the **Project endpoint** from the project welcome or overview page. It ends with `/api/projects/<project-name>`.
3. Open the deployed Claude model and select **Details**.
4. Copy the Claude **Target URI** or **Base URL**, deployment name, and API key shown for the deployment.
5. If the key isn't shown in Foundry, open the Foundry resource in the [Azure portal](https://portal.azure.com).
6. Under **Resource Management**, select **Keys and Endpoint**.
7. Select **Show keys**, then copy **KEY 1** or **KEY 2**.

Both account keys can authenticate Claude inference requests and aren't restricted to one deployment. They aren't a replacement for Microsoft Entra ID when using Foundry project APIs.

### Retrieve them with Azure CLI

Replace the resource-group and account names if you overrode the template defaults:

```bash
RESOURCE_GROUP="rg-foundry-claude-prod"
PROJECT_NAME="foundry-claude-project"
FOUNDRY_NAME="$(
  az cognitiveservices account list \
    --resource-group "$RESOURCE_GROUP" \
    --query "[?kind=='AIServices'].name | [0]" \
    --output tsv
)"

export FOUNDRY_PROJECT_ENDPOINT="https://${FOUNDRY_NAME}.services.ai.azure.com/api/projects/${PROJECT_NAME}"
export CLAUDE_BASE_URL="https://${FOUNDRY_NAME}.services.ai.azure.com/anthropic"
export CLAUDE_TARGET_URI="${CLAUDE_BASE_URL}/v1/messages"
export CLAUDE_DEPLOYMENT_NAME="claude-opus-5-global"
export AZURE_API_KEY="$(
  az cognitiveservices account keys list \
    --resource-group "$RESOURCE_GROUP" \
    --name "$FOUNDRY_NAME" \
    --query key1 \
    --output tsv
)"
```

The Bicep deployment returns `foundryProjectEndpoint`, `claudeBaseUrl`, and `claudeModelDeploymentName` as non-secret outputs. It deliberately doesn't return an API key because ARM deployment outputs and histories shouldn't contain secrets.

### Test the Claude Messages API

```bash
curl --request POST "$CLAUDE_TARGET_URI" \
  --header "Content-Type: application/json" \
  --header "x-api-key: $AZURE_API_KEY" \
  --header "anthropic-version: 2023-06-01" \
  --data "{
    \"model\": \"$CLAUDE_DEPLOYMENT_NAME\",
    \"max_tokens\": 256,
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"Reply with a short confirmation that the deployment is working.\"
      }
    ]
  }"
```

A successful request returns a JSON message response. A `401` usually indicates an invalid key, while a `404` commonly indicates an incorrect resource endpoint or deployment name.

Don't commit API keys or store them in source code, scripts, pipeline variables that aren't secret-protected, or application configuration files. Store production keys in Azure Key Vault and rotate between KEY 1 and KEY 2. Prefer Microsoft Entra ID authentication over account keys for production workloads where possible.

## 9. Configure a USD 200 monthly budget

The Azure portal doesn't create a budget directly at an individual Foundry-resource scope. Use the dedicated resource group as the closest reliable scope.

1. Open `rg-foundry-claude-prod` in the Azure portal.
2. Under **Cost Management**, select **Budgets**.
3. Select **Add**.
4. Confirm that the scope is the dedicated resource group.
5. Configure:
   - **Name:** `budget-foundry-claude-200-usd`
   - **Reset period:** `Monthly`
   - **Start date:** current month
   - **Expiration date:** an appropriate future governance date
   - **Amount:** `200`
6. Select **Next**.
7. Add an **Actual** cost alert at **100%**, corresponding to USD 200 when the billing currency is USD.
8. Add email recipients for the operations and finance teams.
9. Recommended additional warnings:
   - **Actual 80%** for an early warning at USD 160.
   - **Forecasted 100%** when Azure predicts the month will exceed USD 200.
10. Optionally attach an Azure Monitor Action Group.
11. Select **Create**.

Budgets are normally evaluated in the billing account's currency. If that currency isn't USD, convert USD 200 into the billing currency and review the conversion periodically.

## 10. Understand budget limitations

An Azure budget is an alert, not a hard spending cap:

- It doesn't disable the model at USD 200.
- It doesn't reject API calls.
- Cost data can be delayed by 8-24 hours.
- Budgets are generally evaluated every 24 hours.
- A high-volume workload can exceed the threshold before notification.
- Private-offer discounts can make Foundry estimates differ from invoiced costs.

For stronger controls, combine the budget with application-side request limits, token limits, conservative TPM/RPM quota, per-user quotas, usage monitoring, and carefully tested Action Group automation.

## 11. Validate the deployment

Confirm:

- The Foundry resource and project are in the dedicated resource group.
- The model deployment status is `Succeeded`.
- Region scope is Global/Global Standard.
- The intended hosting version is selected.
- The model is generally available if used in production.
- The API target URI and deployment name produce a successful test response.
- Resource-group and Foundry-resource tags are present.
- The monthly budget amount is USD 200 or its billing-currency equivalent.
- Actual and forecasted alerts have valid recipients.
- Recipients can receive messages from `azure-noreply@microsoft.com`.
- Foundry **Monitor** shows per-model request and token usage.
- Azure Cost Management shows actual Marketplace CCU charges.

## References

- [Set up Microsoft Foundry resources](https://learn.microsoft.com/en-us/azure/foundry/tutorials/quickstart-create-foundry-resources)
- [Deploy and use Claude models](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/how-to/use-foundry-models-claude)
- [Foundry deployment types](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/deployment-types)
- [Claude models in Microsoft Foundry](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/claude-models)
- [Claude Consumption Unit billing](https://learn.microsoft.com/en-us/azure/foundry/foundry-models/concepts/claude-models-billing)
- [Create and manage Azure budgets](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-acm-create-budgets)
- [Apply Azure resource tags](https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/tag-resources-portal)
