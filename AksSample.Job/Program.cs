namespace AksSample.Job
{
    internal class Program
    {
        static void Main(string[] args)
        {
            // a potentially long-running job for a tenant
            // e.g. db migration

            var tenant = Environment.GetEnvironmentVariable("TENANT");
            var waitFor = Environment.GetEnvironmentVariable("WAIT_FOR");
            Console.WriteLine($"Running job for {tenant}, waiting for {waitFor}ms");
            Console.WriteLine("2 + 2...let me think...");
            Thread.Sleep(Convert.ToInt32(waitFor));
            Console.WriteLine("The answer is.... 4!");
        }
    }
}