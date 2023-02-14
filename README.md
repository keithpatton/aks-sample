# AKS Sample

## Purpose

Provides a working example of :

- Azure Devops YAML Pipelines which 
    - Build and maintain infrastructure 
    - Handle workload deployments to an AKS Cluster 
- AKS Workload Identity using the Asp.Net Core Api project template with minor modifications. 
    - Accessing Azure SQL with Managed Identity
    - Accessing Key Vault with Managed Identity
- Multi-tenancy Aspects
    - Tenants specified as data, allowing for tenatn groups and also deployment rings for specific workload versions
    - Infrastructure Deployment
      - Azure SQL Database provisioned for each tenant along with appropriate access
    - Application Deployment
      - A Persistent Volume Claim (PVC) automatically creates an NFS mount backed by a blob container for each tenant
      - Support for tenanted Deployment Rings (e.g. tenant1 to stable version and tenant2 gets vnext version)
    - Application Runtime 
      - Tenant is inferred at runtime using a custom header
      - Tenanted SQL database access
      - Tenanted Storage Mount (blob container) is written to.
      - Key Vault updated with tenanted secret (using tenant suffix)
- Devops Aspects
    - Demonstates use of templates to share variables with a deployment stamp approach
    - Demonstrates use of parameter data for tenants, tenant groups and deployment rings to create a dynamic deployment topology

## Pre-requisites
- Azure Account (owner of an Azure Subscription)
- Azure Devops Account (Free version is fine)
- Azure CLI (Cloud Shell is fine)

For Local Development (optional)
- Visual Studio 2022+
- Docker Desktop

## Azure Devops Setup
- Create a Service Connection to your Azure Subscription in Azure Devops which has Owner rights on the Subscription
- Update the svcConnAzureRm variable name in /Devops/Common/Templates/env/dev/variables.yml to your Service Connection Name
- Create 2 pipelines, one called Infra and one called App (your naming is fine)
    - Infra pipeline is at Devops/Infra/Pipelines/azure-pipelines.yml
    - App pipeline is at Devops/App/Pipelines/azure-pipelines.yml

## Variables
All variables are stored in source control:
- Variables common to all pipelines are held in /Devops/Common/Templates
- Variables specific to the infra pipeline are held in /Devops/Infra/Templates
- Variables specific to the app pipeline are held in /Devops/App/Templates

A structure is employed to afford deploymen stamp control with region/environment variable combinations:
- Devops/Common/Templates/reg-env.yml - region and environment variables
- Devops/Common/Templates/env_dev.yml - development environment only variables
- Devops/Common/Templates/reg_au1-env_dev.yml - au1 region and dev environment specific variables

It is advised to update the app_name value (keep it under 12 alphanumeric chars) at /Devops/App/Templates/variables/reg-eng.yml

## Infrastructure Pipeline
This pipeline specifies the steps to be taken to ensure the infrastructure for an environment. 

This pipeline is fully idempotent and needs to be run at least once before the application pipeline. 

## Run Application Pipeline
The application pipeline does the following:
 - Builds and Publishes Image (Optional)
 - Ensures App Specific Infrastructure (e.g. Managed Identities and SQL database access)

Note that the App Specific Infra requires that core Infrastructure pipeline has already run.

## Verify Application is Working
- Execute the following to watch for the EXTERNAL_IP value to be published for the pod: ```watch kubectl get services```
- Make a request to the AKS hosted url endpoint, e.g. http://{{EXTERNAL-IP}}/WeatherForecast with the X-TenantId header set to a tenant (e.g. tenant1)

- You should receive the forecast data in the browser with '(tenant1 is Changeable)' as part of every summary which is the value that is from Key Vault.
- The correct app version correspondign to the version assigned in the deployment ring should show
- This proves the Azure AD Workload Identity is working correctly!
- Files are also written to Azure Blob Containers which you can find within the dynamically provsioned azure storage account within the Kubernetes resource group
- A table called 'example_table' is created if necessary for tenant1
- You can also then change the tenant to say 'tenant2' to validate the request for a different tenant
- (Note: Tenant would be inferred via domain and custom header or JWT token in production)

## Running Locally (TBC)

You can also run things locally afer the pipeline has run successfully the first time with a few steps:

 Configure Key Vault for User:
 - Confirm your account via Tools > Options > Azure Service Authentication > Account Selection.
 - Create a new Key Vault policy with Get/Set privileges on the new key vault resource for this user.
 - Update the keyVaultName variable in WeatheForecastController.cs to match the name of the Key Vault 

 Deploy locally:
 - Switch deploy target to 'ask_mt.api' (Kestrel, not Docker) and then the Azure Managed Identity will work seamlessly using your MS account. 
 - Deploy the app which will bring up the Swagger endpoint, then try out the WeatherForecast endpoint which will be at http://localhost:{{port}}/WeatherForecast 
 - You should receive the forecast data in the browser with '(Changeable)' as part of every summary which is the value that is from Key Vault.
 - You should also see files created in C:\Temp\AksWorkloadIdentitySample\ (which in AKS would write to Azure Blob Storage containers)

## What changes were applied to the project template? (TBC)
The template app provides a simple weather forecast api which is a simple GET to the /WeatherForecast endpoint. 

- Azure.Identity and Azure.Security.KeyVault.Secrets Nuget Packages were added to the project.
- WeatherForecastController.cs was updated to write to persistent storage, access Key Vault, create and retrieve a secret using Azure Managed Identity, then return within the response summary.
- These changes are enough to prove that the Azure AD Managed Identity is being used and that Azure Blob Storage could be used for shared storage.

```
        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {

            // test out writing to persistent volume storage
            WriteToPersistentStorage();

            // use Azure AD Identity to create and retrieve a new secret, then use it within the response within Summary
            // this proves the Azure AD Identity flow is working 
            var keyVaultName = "aks-sandbox2-kv";
            var client = new SecretClient(new Uri($"https://{keyVaultName}.vault.azure.net/"), new DefaultAzureCredential());
            client.SetSecret(new KeyVaultSecret("kvsecret", "(Changeable)"));
            var secret = client.GetSecret("kvsecret")?.Value;

            return Enumerable.Range(1, 5).Select(index => new WeatherForecast
            {
                Date = DateTime.Now.AddDays(index),
                TemperatureC = Random.Shared.Next(-20, 55),
                Summary = $"{Summaries[Random.Shared.Next(Summaries.Length)]} - {secret?.Value}"
            })
            .ToArray();
        }

```

## Links
- https://azure.github.io/azure-workload-identity/docs/quick-start.html
- https://github.com/epomatti/azure-workload-identity-terraform
