using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;

namespace AksWorkloadIdentitySample.Api.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class WeatherForecastController : ControllerBase
    {
        private static readonly string[] Summaries = new[]
        {
            "Freezing", "Bracing", "Chilly", "Cool", "Mild", "Warm", "Balmy", "Hot", "Sweltering", "Scorching"
        };

        private readonly ILogger<WeatherForecastController> _logger;

        public WeatherForecastController(ILogger<WeatherForecastController> logger)
        {
            _logger = logger;
        }

        [HttpGet(Name = "GetWeatherForecast")]
        public IEnumerable<WeatherForecast> Get()
        {
            // Write To persistent volume storage
            WriteToPersistentStorage();

            try
            { 
                // Access DB Using Managed Identity
                var sqlServerName = Environment.GetEnvironmentVariable("sql_server_name");
                if (String.IsNullOrWhiteSpace(sqlServerName))
                    sqlServerName = "sql-au1-dev-01"; // update for local dev        
                var connString = $"Data Source={sqlServerName}.database.windows.net; Initial Catalog=tenant1; Encrypt=True";
                using SqlConnection conn = new SqlConnection(connString);
                var credential = new Azure.Identity.DefaultAzureCredential();
                var token = credential.GetToken(new Azure.Core.TokenRequestContext(new[] { "https://database.windows.net/.default" }));
                conn.AccessToken = token.Token;
                conn.Open();
            }
            catch (Exception ex)
            {
                Console.Write("Unable to connect to Azure SQL Database"));
                Console.Write(ex.ToString());
            }

            // Use Azure AD Identity to create and retrieve a new secret, then use it within the response within Summary
            var keyVaultName = Environment.GetEnvironmentVariable("aks_keyvault");
            if (String.IsNullOrWhiteSpace(keyVaultName))
                keyVaultName = "kv-aksdemo-qpe"; // update for local dev
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

        /// <summary>
        /// Tests out writing to azure blob storage backed persistent volumes which map to separate azure blob containers
        /// </summary>
        private void WriteToPersistentStorage()
        {
            // write to shared storage 
            var commonFolder = "common";
            var tenant1Folder = "tenant1";
            var tenant2Folder = "tenant2";

            var commonPath = $"/var/{commonFolder}/";
            var tenant1Path = $"/var/{tenant1Folder}/";
            var tenant2Path = $"/var/{tenant2Folder}/";

            if (String.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("KUBERNETES_SERVICE_HOST")))
            {
                // not running in K8s, assume local windows pc
                var localRoot = @"C:\Temp\AksWorkloadIdentitySample\";
                commonPath = $"{localRoot}{commonFolder}";
                tenant1Path = $"{localRoot}{tenant1Folder}";
                tenant2Path = $"{localRoot}{tenant2Folder}";
                if (!Directory.Exists(commonPath))
                    Directory.CreateDirectory(commonPath);
                if (!Directory.Exists(tenant1Path))
                    Directory.CreateDirectory(tenant1Path);
                if (!Directory.Exists(tenant2Path))
                    Directory.CreateDirectory(tenant2Path);
            }

            var fileName = $"{DateTime.Now.Hour}-{DateTime.Now.Minute}-{DateTime.Now.Second}.txt";
            var commonFileName = Path.Combine(commonPath, fileName);
            var tenant1FileName = Path.Combine(tenant1Path, fileName);
            var tenant2FileName = Path.Combine(tenant2Path, fileName);
            System.IO.File.WriteAllText(commonFileName, "Weather Forecast was requested - common");
            System.IO.File.WriteAllText(tenant1FileName, "Weather Forecast was requested - tenant 1");
            System.IO.File.WriteAllText(tenant2FileName, "Weather Forecast was requested - tenant 2");
        }

    }
}