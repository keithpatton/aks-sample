# AKS Sample

## Purpose

Provides a working example of :

- Azure Devops YAML Pipelines to build and maintain infrastructure and handle application deployment to an AKS Cluster
    - Using Terraform for Infrastructure and Helm for Application provisioning
- AKS Workload Identity using the Asp.Net Core Api project template with minor modifications. 
    - Accessing Azure SQL with Managed Identity
    - Accessing Key Vault with Managed Identity
- Multi-tenancy Aspects
    - Tenants specified as pipeline parameters (e.g tenant1, tenant2)
    - Azure SQL Database created for each Tenant
    - A dynamically provisioned Kubernetes Persistent Volume for each tenant (backed by Azure Blob Storage)
- Devops Aspects
    - Azure Devops use of parallel build agents to implement tenant specific work where necessary
    - Demonstates use of templates to share variables with a deployment stamp approach

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
- Devops/Common/Templates/env/dev/variables/yml
- Devops/Common/Templates/region/au1/variables.yml
- Devops/Common/Templates/region-env/au1-dev/variables.yml

It is advised only to update the app_name value (keep it under 12 alphanumeric chars) at /Devops/Common/Templates/variables.yml.

## Infrastructure Pipeline
This pipeline specifies the steps to be taken to ensure the infrastructure for an environment. 

The pipeline is triggered manually and has several parameters:

- region, environment 
    - Fixed at present, but combined with the variable structure above showcases flexibility for various deployment stamps
- tenants - Can be altered to add/remove tenants. 
    - e.g. Each tenant is provisioned with their own database to which the AKS cluster has access
- destroy infra (before apply) 
    - Allows for infra to be destroyed before being applied, defaults to false
- apply infra 
    - Allows for control over whether infra is applied, defaults to true

This pipeline is fully idempotent and needs to be run at least once before the application pipeline. 


## Run Application Pipeline (TBC)
TODO 
 - Builds and Publishes Image
 - Deploys to AKS (Helm)

## Verify Application is Working (TBC)
- Execute the following to watch for the EXTERNAL_IP value to be published for the pod: ```watch kubectl get services```
- Browse to the AKS hosted url endpoint, e.g. http://{{EXTERNAL-IP}}/WeatherForecast 
- You should receive the forecast data in the browser with '(Changeable)' as part of every summary which is the value that is from Key Vault.
- This proves the Azure AD Workload Identity is working correctly!
- Files are also written to Azure Blob Containers which you can find within the dynamically provsioned azure storage account within the resource group "sandbox-aks-nodes-rg"


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
