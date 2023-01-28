# AKS Sample

## Purpose
Provides a working example of :
- AKS Workload Identity using the Asp.Net Core Api project template with minor modifications. 
- Dynamically provisioned Persistent Volumes backed by Azure Blob Storage

Uses Terraform to provision infrastructure and deploy the application using the Azure and Helm Providers.

## Pre-requisites
- Azure Account to create/manage resources on Azure Subscription and Azure AD tenancy
- Visual Studio 2022+
- Docker Desktop
- Azure CLI
- Terraform - Ensure [Authenticated for Azure](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure)
- Helm

### Configure Azure AD Workload Identity (Preview)
```
az extension add --name aks-preview
az feature register --namespace "Microsoft.ContainerService" --name "EnableWorkloadIdentityPreview"
az provider register --namespace Microsoft.ContainerService
```

## Check Variables
Terraform is used to provision infrastructure and deploy the application (using the Helm Provider).

Within the Terraform folder:
- shared.tfvars - values used for infrastructure and application deployment. 
- infra.tfvars - values used only as part of the infrastructure provisioning

It is advised only to update the app_name value (keep it under 12 alphanumeric chars) within shared.tfvars.

## Create Infrastructure
Run from from within the project directory:
```
terraform -chdir="Terraform/Infrastructure" init
terraform -chdir="Terraform/Infrastructure" apply -auto-approve -var-file="..\shared.tfvars" -var-file="..\infra.tfvars"
```

## Publish Application Image to the Container Registry
- Right-click the project in Visual Studio and select 'Publish'.
- Select Docker Container Registry > Azure Container Registry.
- Select the resource group used during setup and then the name of the ACR that was created with terraform earlier
- Click on Publish button which will build and deploy your application image to the ACR.

## Deploy Application to AKS Cluster
Run from from within the project directory:
```
terraform -chdir="Terraform/Deploy" init
terraform -chdir="Terraform/Deploy" apply -auto-approve -var-file="..\shared.tfvars" 
```

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
To clean up all resourcs, run from from within the project directory:
 ```
terraform -chdir="Terraform/Deploy" destroy -auto-approve -var-file="..\shared.tfvars"
terraform -chdir="Terraform/Infrastructure" destroy -auto-approve -var-file="..\shared.tfvars" -var-file="..\infra.tfvars"
```

## Running Locally 

You can also run things locally with a few steps:

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
