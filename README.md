# AKS Workload Identity Sample

## Purpose
Provides a working example of AKS Workload Identity using the Asp.Net Core Api project template with minor modifications. 

## Pre-requistes
- Azure Subscription Account with sufficient priviliges to create/manage resources.
- Visual Studio 2022+.
- Docker Desktop.

## Setup Azure Environment
- Open setup.sh set ACR_NAME and KEYVAULT_NAME variables as must be globally unique (others you can leave or update as required).
- Using Azure Cloud Shell bash, upload setup.sh and execute using: ```bash setup.sh```.
- This step will create all the necessary Azure resources using Azure CLI and kubectl (will take a fe mins).
- This script is idempotent so can be re-run if necessary
- Keep Azure Cloud Shell session alive as we'll use it for the deploy step below.

## Deploy Application Locally 
- *Important*: Update the keyVaultName variable in WeatheForecastController.cs to match the KEYVAULT_NAME value used in the Setup step.
 - Check that you are logged into Visual Studio with an account that has priviliges on the Key Vault resource. 
 - You can confirm your account via Tools > Options > Azure Service Authentication > Account Selection.
 - If you switch to use 'IIS Express' as the deploy target (not Docker) then this Azure Managed Identity will work seamlessly using this MS account. 
 - Deploy the app which will bring up the Swagger endpoint, then try out the WeatherForecast endpoint which will be at http://localhost:{{port}}/WeatherForecast 
 - You should receive the forecast data in the browser with '(Changeable)' as part of every summary which is the value that is from Key Vault.
 - We should see the exact same thing after we deploy the application to AKS with no additional code changes.

## Publish Application Image to the Container Registry
- Right-click the project in Visual Studio and select 'Publish'.
- Select Docker Container Registry > Azure Container Registry.
- Select the resource group used during setup and then the name of the ACR we created in during setup.
- Click on Publish button which will build and deploy your application image to the ACR.

## Deploy Application to the AKS Cluster
- Open deploy.sh and ACR_NAME to the same value you chose for setup.sh
- Using your open Azure Cloud Shell session, upload deploy.sh and execute using: ```bash deploy.sh```.
- This will deploy your application into the AKS cluster and expose it on port 80. (obviously only suitable for development!).
- Execute the following to watch for the EXTERNAL_IP value to be published for the pod: ```watch kubectl get services```
- Browse to the AKS hosted url endpoint, e.g. http://{{EXTERNAL-IP}}/WeatherForecast 
- You should receive the json with "(Changeable)" in the summary from key vault as within your local dev environment.
- This proves the Azure AD Workload Identity is working correctly!

## Conclusion
- Azure AD Workload Identity for AKS greatly simplifies application access to Azure Resources by using Azure Managed Identity directly from within your applications. 
- This example uses Azure Key Vault, but the same principle would apply to other Azure Managed Identity aware resources such as Azure SQL and Azure Storage.
- You can clean up and delete resources by simply deleting the resource group you created using setup.sh.

## What changes were applied to the project template?
The template app provides a simple weather forecast api which is a simple GET to the /WeatherForecast endpoint. 

- Azure.Identity and Azure.Security.KeyVault.Secrets Nuget Packages were added to the project.
- WeatherForecastController.cs was updated to access Key Vault, create and retrieve a secret using Azure Managed Identity, then return within the response summary.
- These changes are enough to prove that the Azure AD Managed Identity is being used which is the purpose of the sample.

```
        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {
            // use Azure AD Identity to create and retrieve a new secret, then use it within the response within Summary
            // this proves the Azure AD Identity flow is working 
            var keyVaultName = "vista-sandbox2-kv";
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
https://azure.github.io/azure-workload-identity/docs/quick-start.html