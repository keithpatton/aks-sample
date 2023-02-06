using Azure.Identity;
using Azure.Security.KeyVault.Secrets;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using System.Linq;
using System.Text.Json;

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
        public IEnumerable<WeatherForecast> Get(string tenant)
        {

            // Write to persistent volume storage
            WriteToPersistentStorage(tenant);

            // Use Azure AD Identity to create and retrieve a new secret, then use it within the response within Summary
            var keyVaultName = IsInAks() ? Environment.GetEnvironmentVariable("aks_keyvault") : "kv-au1-dev-aksdemo-01";
            var client = new SecretClient(new Uri($"https://{keyVaultName}.vault.azure.net/"), new DefaultAzureCredential());
            client.SetSecret(new KeyVaultSecret($"kvsecret{tenant}", $"({tenant} is Changeable)"));
            var secret = client.GetSecret($"kvsecret{tenant}")?.Value;

            // Access Tenant DB Using Managed Identity and create table if not already existing
            var sqlServerName = IsInAks() ? Environment.GetEnvironmentVariable("sql_server_name") : "sql-au1-dev-01";
            var connString = $"Data Source={sqlServerName}.database.windows.net; Initial Catalog={tenant}; Encrypt=True";
            using SqlConnection conn = new SqlConnection(connString);
            var credential = new Azure.Identity.DefaultAzureCredential();
            var token = credential.GetToken(new Azure.Core.TokenRequestContext(new[] { "https://database.windows.net/.default" }));
            conn.AccessToken = token.Token;
            conn.Open();

            using (SqlCommand command = new SqlCommand("IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'example_table') CREATE TABLE example_table (id INT PRIMARY KEY, name VARCHAR(255), date_created DATETIME DEFAULT GETDATE());", conn))
            command.ExecuteNonQuery();

            // return result
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
        private void WriteToPersistentStorage(string tenant)
        {
            // write to shared storage 
            var commonFolder = "common";

            var commonPath = $"/var/{commonFolder}/";
            var tenantPath = $"/var/{tenant}/";

            if (!IsInAks())
            {
                // not running in K8s, assume local windows pc
                var localRoot = @"C:\Temp\AksWorkloadIdentitySample\";
                commonPath = $"{localRoot}{commonFolder}";
                tenantPath = $"{localRoot}{tenantPath}";
                if (!Directory.Exists(commonPath))
                    Directory.CreateDirectory(commonPath);
                if (!Directory.Exists(tenantPath))
                    Directory.CreateDirectory(tenantPath);
            }

            var fileName = $"{DateTime.Now.Hour}-{DateTime.Now.Minute}-{DateTime.Now.Second}.txt";
            var commonFileName = Path.Combine(commonPath, fileName);
            var tenant1FileName = Path.Combine(tenantPath, fileName);
            System.IO.File.WriteAllText(commonFileName, "Weather Forecast was requested - common");
            System.IO.File.WriteAllText(tenant1FileName, $"Weather Forecast was requested - {tenant}");
        }

        private bool IsInAks()
        {
            return !String.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("KUBERNETES_SERVICE_HOST"));
        }

    }
}