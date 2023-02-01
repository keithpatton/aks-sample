# AKS Sample

## Purpose
Provides a working example of :
- AKS Workload Identity using the Asp.Net Core Api project template with minor modifications. 
- Dynamically provisioned Persistent Volumes backed by Azure Blob Storage

Uses Azure Devops Pipelines to provision infrastructure with Terraform and deploy the application using Helm.

## Pre-requisites
- Azure Account (owner of an Azure Subscription)
- Azure Devops Account (Free version is fine)
- Azure CLI (Cloud Shell is fine)

For Local Development (optional)
- Visual Studio 2022+
- Docker Desktop

### Configure Azure AD Workload Identity (Preview)
TODO: Move to AzD Pipeline
```
az extension add --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az provider register --namespace Microsoft.ContainerService
```

## Azure Devops SetUp
TODO: Finalise Doco
- Create new pipeline and point to azure-pipelines.yml 
- Ensure service connection set to to Azure
- Ensure service connection has Owner rights on subscription
- Check over variables and update as required
  - It is advised only to update the app_name value (keep it under 12 alphanumeric chars) within shared.tfvars.

## Run Pipeline
TODO: Finalise Doco
 - Creates/Updates Infrastructure (Terraform)
 - Builds and Publishes Image
 - Deploys to AKS (Helm)

## Verify Application is Working
- Execute the following to watch for the EXTERNAL_IP value to be published for the pod: ```watch kubectl get services```
- Browse to the AKS hosted url endpoint, e.g. http://{{EXTERNAL-IP}}/WeatherForecast 
- You should receive the forecast data in the browser with '(Changeable)' as part of every summary which is the value that is from Key Vault.
- This proves the Azure AD Workload Identity is working correctly!
- Files are also written to Azure Blob Containers which you can find within the dynamically provsioned azure storage account within the resource group "sandbox-aks-nodes-rg"

## Conclusion
- Azure AD Workload Identity for AKS greatly simplifies application access to Azure Resources by using Azure Managed Identity directly from within your applications. 
- This example uses Azure Key Vault, but the same principle would apply to other Azure Managed Identity aware resources such as Azure SQL and Azure Storage.
- Azure Blob Storage is used with dynamically provisioned Persitent Volumes which allow for persisent storage which can be shared between pods.

## Clean Up
 - TODO - TF Destroy Pipeline

## Running Locally 

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

## What changes were applied to the project template?
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
