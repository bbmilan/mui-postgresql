using Microsoft.EntityFrameworkCore;
using Npgsql;
using Azure.Core;
using Azure.Identity;
using AzurePostgreSQLServerConfiguration;


var builder = WebApplication.CreateBuilder(args);

var azureDatabaseSettings = new AzureDatabaseSettings();
builder.Configuration.GetSection("AzurePostgreSql").Bind(azureDatabaseSettings);

string host = azureDatabaseSettings.Host;
string database = azureDatabaseSettings.Database;
int port = azureDatabaseSettings.Port;
string username;
DefaultAzureCredential credential;

// Determine if running locally
var isDevelopment = builder.Environment.IsDevelopment();

if (isDevelopment)
{
    // Local development settings
    username = builder.Configuration["MicrosoftEntraUserID"] ?? throw new InvalidOperationException("MicrosoftEntraUserID is not configured");

    // Use DefaultAzureCredential without ManagedIdentityClientId
    credential = new DefaultAzureCredential();
}
else
{
    // Azure settings
    username = builder.Configuration["AzurePostgreSQLEntraUserID"] ?? throw new InvalidOperationException("AzurePostgreSQLEntraUserID is not provided");
    var managedIdentityClientId = builder.Configuration["ManagedIdentityClientId"] ?? throw new InvalidOperationException("Managed Identity Client ID is not provided");

    var defaultAzureCredentialOptions = new DefaultAzureCredentialOptions
    {
        ManagedIdentityClientId = managedIdentityClientId
    };
    credential = new DefaultAzureCredential(defaultAzureCredentialOptions);
}

// Build the base connection string without password
var connectionString = $"Host={host};Port={port};Database={database};Username={username};Ssl Mode=Require;Trust Server Certificate=true;";

// **Token-Based Authentication (Azure AD)**

// Define the token request context
var tokenRequestContext = new TokenRequestContext(new[] { "https://ossrdbms-aad.database.windows.net/.default" });

// Create the NpgsqlDataSource with token refresh capabilities
var dataSourceBuilder = new NpgsqlDataSourceBuilder(connectionString);

// Configure the periodic password provider
dataSourceBuilder.UsePeriodicPasswordProvider(
    async (_, ct) =>
    {
        // Acquire the access token using DefaultAzureCredential
        AccessToken tokenResponse = await credential.GetTokenAsync(tokenRequestContext, ct);
        return tokenResponse.Token;
    },
    TimeSpan.FromHours(4),
    TimeSpan.FromSeconds(10)
);

// Build the data source
var dataSource = dataSourceBuilder.Build();

builder.Services.AddControllers();


// Register the DbContext with the configured data source
builder.Services.AddDbContext<TodoDb>(options =>
    options.UseNpgsql(dataSource));

// Add Swagger services
builder.Services.AddDatabaseDeveloperPageExceptionFilter();
builder.Services.AddEndpointsApiExplorer();

builder.Services.AddOpenApiDocument(config =>
{
    config.DocumentName = "TodoAPI";
    config.Title = "TodoAPI v1";
    config.Version = "v1";
});

var app = builder.Build();

// Use Swagger middleware
app.UseOpenApi();
app.UseSwaggerUi(config =>
{
    config.DocumentTitle = "TodoAPI";
    config.Path = "/swagger";
    config.DocumentPath = "/swagger/{documentName}/swagger.json";
    config.DocExpansion = "list";
});

app.MapControllers();

app.Run();
