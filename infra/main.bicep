@description('Globally unique Foundry account name.')
param foundryName string = 'aif-${take(uniqueString(subscription().subscriptionId, resourceGroup().id), 10)}'

@description('Foundry project name.')
param projectName string = 'foundry-claude-project'

@description('Azure region for the Foundry account and project.')
param location string = 'eastus2'

@description('Claude model ID available in the selected region.')
param claudeModelName string = 'claude-opus-5'

@description('Claude model version.')
param claudeModelVersion string = '1'

@description('Name applications use to address this deployment.')
param claudeDeploymentName string = 'claude-opus-5-global'

@description('Global Standard capacity in thousands of tokens per minute.')
@minValue(1)
param claudeCapacity int = 25

@description('Legal organization name used to accept the Anthropic Marketplace offer.')
@minLength(1)
param claudeOrganizationName string

@description('Two-letter ISO country code for the legal organization.')
@minLength(2)
@maxLength(2)
param claudeCountryCode string

@description('Industry used to accept the Anthropic Marketplace offer.')
@allowed([
  'technology'
  'finance'
  'healthcare'
  'education'
  'retail'
  'manufacturing'
  'government'
  'media'
  'other'
])
param claudeIndustry string = 'technology'

@description('Email address that receives the monthly budget notifications.')
@minLength(3)
param budgetAlertEmail string

@description('Monthly resource-group budget in the billing currency. Set to 200 for a USD 200 budget on USD billing accounts.')
@minValue(1)
param monthlyBudgetAmount int = 200

@description('First day from which the monthly budget is evaluated.')
param budgetStartDate string = utcNow('yyyy-MM-01')

@description('Budget expiration date.')
param budgetEndDate string = dateTimeAdd(utcNow(), 'P5Y', 'yyyy-MM-dd')

@description('Governance tags applied to the Foundry account and project.')
param tags object = {
  Service: 'MicrosoftFoundry-Claude'
  Environment: 'Production'
  CostCenter: 'AI-001'
  Application: 'ClaudeApplication'
  ManagedBy: 'PlatformEngineering'
  BudgetLimitUSD: '200'
  DataClassification: 'Internal'
}

resource foundry 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: foundryName
  location: location
  tags: tags
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    allowProjectManagement: true
    customSubDomainName: foundryName
    disableLocalAuth: false
    publicNetworkAccess: 'Enabled'
  }
}

resource project 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: foundry
  name: projectName
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {}
}

resource claudeDeployment 'Microsoft.CognitiveServices/accounts/deployments@2025-10-01-preview' = {
  parent: foundry
  name: claudeDeploymentName
  sku: {
    name: 'GlobalStandard'
    capacity: claudeCapacity
  }
  properties: {
    model: {
      format: 'Anthropic'
      name: claudeModelName
      version: claudeModelVersion
    }
    // Required by Claude deployments; current Bicep type metadata doesn't expose it yet.
    #disable-next-line BCP037
    modelProviderData: {
      organizationName: claudeOrganizationName
      countryCode: toUpper(claudeCountryCode)
      industry: claudeIndustry
    }
    versionUpgradeOption: 'OnceNewDefaultVersionAvailable'
    raiPolicyName: 'Microsoft.DefaultV2'
  }
  dependsOn: [
    project
  ]
}

resource budget 'Microsoft.Consumption/budgets@2023-11-01' = {
  name: 'budget-foundry-claude-200'
  properties: {
    amount: monthlyBudgetAmount
    category: 'Cost'
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: budgetStartDate
      endDate: budgetEndDate
    }
    notifications: {
      Actual80Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: [
          budgetAlertEmail
        ]
      }
      Actual100Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: [
          budgetAlertEmail
        ]
      }
      Forecasted100Percent: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Forecasted'
        contactEmails: [
          budgetAlertEmail
        ]
      }
    }
  }
}

output foundryAccountName string = foundry.name
output foundryProjectName string = project.name
output foundryProjectEndpoint string = 'https://${foundry.name}.services.ai.azure.com/api/projects/${project.name}'
output claudeBaseUrl string = 'https://${foundry.name}.services.ai.azure.com/anthropic'
output claudeModelDeploymentName string = claudeDeployment.name
output monthlyBudgetName string = budget.name
