@description('Budget amount in the subscription billing currency. Verify currency before deploying.')
@minValue(1)
param monthlyBudget int = 30
@description('Verified email addresses for the PM and team.')
@minLength(1)
param contactEmails array
@description('First day of the current month, for example 2026-11-01.')
param budgetStart string
@description('Budget validity. This does not stop or delete resources.')
param budgetEnd string = '2027-01-01'

resource budget 'Microsoft.Consumption/budgets@2024-08-01' = {
  name: 'gearpass-monthly'
  properties: {
    amount: monthlyBudget
    category: 'Cost'
    timeGrain: 'Monthly'
    timePeriod: {
      startDate: '${budgetStart}T00:00:00Z'
      endDate: '${budgetEnd}T00:00:00Z'
    }
    notifications: {
      half: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 50
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      high: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 80
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
      limit: {
        enabled: true
        operator: 'GreaterThanOrEqualTo'
        threshold: 100
        thresholdType: 'Actual'
        contactEmails: contactEmails
      }
    }
  }
}
