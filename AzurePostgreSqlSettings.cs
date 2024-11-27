namespace AzurePostgreSQLServerConfiguration
{
    public class AzureDatabaseSettings
    {
        public string Host { get; set; } = string.Empty;
        public string Database { get; set; } = string.Empty;
        public int Port { get; set; }
        public string Username { get; set; } = string.Empty;
    }
}
