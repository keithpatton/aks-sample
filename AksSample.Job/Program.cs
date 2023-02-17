using Microsoft.Data.SqlClient;

namespace AksSample.Job
{
    internal class Program
    {
        static void Main(string[] args)
        {
            // a potentially long-running job for a tenant
            // e.g. db migration

            var tenant = Environment.GetEnvironmentVariable("TENANT");
            var sqlServerName = Environment.GetEnvironmentVariable("SQL_SERVER_NAME");

            Console.WriteLine($"Running job for {tenant} using {sqlServerName}");

            // Access Tenant DB Using Managed Identity and create table if not already existing
            var connString = $"Data Source={sqlServerName}.database.windows.net; Initial Catalog={tenant}; Encrypt=True";
            using SqlConnection conn = new SqlConnection(connString);
            var credential = new Azure.Identity.DefaultAzureCredential();
            var token = credential.GetToken(new Azure.Core.TokenRequestContext(new[] { "https://database.windows.net/.default" }));
            conn.AccessToken = token.Token;
            conn.Open();

            using (SqlCommand command = new SqlCommand("IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'init_job') CREATE TABLE init_job (id INT PRIMARY KEY, name VARCHAR(255), date_created DATETIME DEFAULT GETDATE());", conn))
            command.ExecuteNonQuery();

            Console.WriteLine($"Completed job for {tenant} using {sqlServerName}");

        }

    }
}