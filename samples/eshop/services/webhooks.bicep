extension radius

// PARAMETERS ---------------------------------------------------------

@description('Radius application ID')
param application string

@description('Container registry to pull from, with optional path.')
param imageRegistry string

@description('Container image tag to use for eshop images')
param imageTag string

@description('Name of the Gateway')
param gatewayName string

@description('The name of the Webhooks SQL portable resource')
param sqlWebhooksDbName string

@description('The connection string for the event bus')
@secure()
param eventBusConnectionString string

@description('Use Azure Service Bus for messaging. Allowed values: "True", "False".')
@allowed([
  'True'
  'False'
])
param AZURESERVICEBUSENABLED string

// CONTAINERS -----------------------------------------------------------

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-api
resource webhooks 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webhooks-api'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webhooks.api:${imageTag}'
      env: {
        PATH_BASE: {
          value: '/webhooks-api'
        }
        ASPNETCORE_ENVIRONMENT: {
          value: 'Development'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        ORCHESTRATOR_TYPE: {
          value: 'K8S'
        }
        AzureServiceBusEnabled: {
          value: AZURESERVICEBUSENABLED
        }
        ConnectionString: {
          value: sqlWebhooksDb.listSecrets().connectionString
        }
        EventBusConnection: {
          value: eventBusConnectionString
        }
        identityUrl: {
          value: 'http://identity-api:5105'
        }
        IdentityUrlExternal: {
          value: '${gateway.properties.url}/identity-api'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5113
        }
      }
      livenessProbe: {
        kind: 'httpGet'
        path: '/liveness'
        containerPort: 80
      }
      readinessProbe: {
        kind: 'httpGet'
        path: '/hc'
        containerPort: 80
      }
    }
    connections: {
      sql: {
        source: sqlWebhooksDb.id
        disableDefaultEnvVars: true
      }
      identity: {
        source: 'http://identity-api:5105'
        disableDefaultEnvVars: true
      }
    }
  }
}

// Based on https://github.com/dotnet-architecture/eShopOnContainers/tree/dev/deploy/k8s/helm/webhooks-web
resource webhooksclient 'Applications.Core/containers@2023-10-01-preview' = {
  name: 'webhooks-client'
  properties: {
    application: application
    container: {
      image: '${imageRegistry}/webhooks.client:${imageTag}'
      env: {
        ASPNETCORE_ENVIRONMENT: {
          value: 'Production'
        }
        ASPNETCORE_URLS: {
          value: 'http://0.0.0.0:80'
        }
        PATH_BASE: {
          value: '/webhooks-web'
        }
        Token: {
          value: 'WebHooks-Demo-Web'
        }
        CallBackUrl: {
          value: '${gateway.properties.url}/webhooks-client'
        }
        SelfUrl: {
          value: 'http://webhooks-client:5114'
        }
        WebhooksUrl: {
          value: 'http://webhooks-api:5113'
        }
        IdentityUrl: {
          value: '${gateway.properties.url}/identity-api'
        }
      }
      ports: {
        http: {
          containerPort: 80
          port: 5114
        }
      }
    }
    connections: {
      webhooks: {
        source: 'http://webhooks-api:5113'
      }
      identity: {
        source: 'http://identity-api:5105'
      }
    }
  }
}

// NETWORKING ----------------------------------------------

resource gateway 'Applications.Core/gateways@2023-10-01-preview' existing = {
  name: gatewayName
}

// PORTABLE RESOURCES -----------------------------------------------------------

resource sqlWebhooksDb 'Applications.Datastores/sqlDatabases@2023-10-01-preview' existing = {
  name: sqlWebhooksDbName
}
