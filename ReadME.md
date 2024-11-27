
# Use User Assigned Managed Identity with Azure PostgreSQL Flexible Server and .NET Web API
<p align="left">
    <img src="https://github.com/bbmilan/mui-postgresql/blob/main/imgs/Img-9.png" alt="Design Image">
</p>


PostgreSQL is a robust, open-source relational database system that supports a wide variety of data types and advanced features. When combined with .NET, developers can leverage a powerful ecosystem for building enterprise-grade applications. Adding Microsoft Entra ID (formerly Azure AD) ensures your app is secure with robust authentication and authorization mechanisms. More precisely, using Entra ID, instead of username and password when authenticating your API calls to PostgreSQL database sounds like a great way to secure the access to your data and ensure that only right people have access to it.

This documentation covers all you need to do implement it properly.

In this demo, we will:

- provision infrastructure required to run this demo
- implement Entra ID authentication for Azure Web App to access PostgreSQL database on Azure PostgreSQL Flexible Server
- test it locally and on Azure


# Problem statement
Many software engineers use the [DefaultAzureCredential](https://learn.microsoft.com/en-us/dotnet/api/azure.identity.defaultazurecredential?view=azure-dotnet) class along with AZURE_CLIENT_ID to aquire a token for Azure Web App or Azure Function's user assigned managed identity from Microsoft Entra, which is then passed on when making calls to other services within the system. This works pretty well, with a caveat that this token, once issued is valid for 24 hours and it's cached by the underlining Azure infrastructure for performance and resiliency purposes. In another words, the token issued to a managed identity by Microsoft Entra isn't possible to forcebly refresh during its validity time. How do we handle token refresh in our API or Application when time comes ? How do we ensure seamless user experience for a web API, to keep working properly and without errors when a new token is issued in 24 hours? How do we handle this situation?

# Solution
In this demo, I used an elegant way to manage token expiry and retrieval for a user-assigned managed identiy, with Periodic Password Provider, which is available within Npgsql NuGet package. It is basically all handled for you, so no need to put additional efforts. In the Program.cs you may notice this part:


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
    


# How to run this demo?

1. Clone the repository:
    ```sh
    git clone  https://github.com/bbmilan/mui-postgresql.git
    ```

2. Open the terminal window and type the following command to provision required infrastructure on Azure:

    ```sh
    bash deployment-script.sh
    ```
    
    It may take between 5-10 minutes for the Azure Resource Manager to provision and configure the required infrastructure. 
    
    - Web App ServicePlan,
    - Azure Web App, 
    - Azure PostgreSQL Flexible Server, 
    - Server Admin User, 
    - PostgreSQL Database,
    - Microsoft Entra admin assignment for Azure PostgreSQL Flexible Server, 
    - Firewall rules configuration,
    - User-assigned managed identity, 
    - Identity assignment to the Azure Web App 
    - Establish connection between Azure Web App and Azure PostgreSQL Flexible Server, 
    - Entra role in Azure PostgreSQL Flexible Server (this is done automatically by establishing connection from above)


3. Connect to your Azure PostgreSQL Flexible Server (for example using Pg Admin 4), using server admin credentials from above.

    ![Login Image]https://github.com/bbmilan/mui-postgresql/blob/main/imgs/Img-2.png)

    
4. (Optional) - You can also use the Entra Admin user from above to connect to your PostgreSQL Server, but you will need to obtain the access token from Microsoft Entra and use it instead of password.


            milanjugovic@Marinas-MacBook-Air TodoApi % az account get-access-token --resource https://ossrdbms-aad.database.windows.net
            {
            "accessToken": "your access token",
            "expiresOn": "2024-11-27 12:31:43.000000",
            "expires_on": 1732707103,
            "subscription": "your subscription ID",
            "tenant": "your tenant",
            "tokenType": "Bearer"
            }
    

5. Run the deployment.pgsql query against the todo_db (either from your VS Code or in Pg Admin4 tool)

    ![SQL Script Image](https://github.com/bbmilan/mui-postgresql/blob/main/imgs/Img-3.png)




With this step, the infrastructure provisioning and database setup have been completed succesfully. 
Now we have 2 options - to run the API locally or to deploy it on Azure and test it. 

Let's get started with the option 1 and see what esle is needed to run this API locally, without exposing passwords in the connection string to connect the API with PostgreSQL database.


### Option 1: Running the API Locally

1. **Make changes in the appsettings.json file. You should replace the Host, MicrosoftEntraUserId and ManagedIdentityClientId values with your own**:

    ```sh
        {
        "Logging": {
            "LogLevel": {
            "Default": "Information",
            "Microsoft.AspNetCore": "Warning"
            }
        },
        "AllowedHosts": "*",
        "AzurePostgreSql": {
            "Host": "papajaukserver.postgres.database.azure.com",
            "Database": "todo_db",
            "Port": 5432,
            "Username": "leave-blank"
        },
        "MicrosoftEntraUserID": "milan@walkonthetechside.com",
        "AzurePostgreSQLEntraUserID": "aad_postgresql_988c7",
        "ManagedIdentityClientId": "099ad395-9982-4242-ba37-f5260c2aa5fe"
        }
    ```



2. **In Pg Admin 4 studio, you will need to assign the right permissions to your Microsoft Entra User ID that you will use**:

    To simplify the things, I will use the same user that I assigned to be the Microsoft Entra Admin for my Azure PostgreSQL Server (milan@walkonthetechside.com)

    ```sh
    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE todoschema."Todo" TO "milan@walkonthetechside.com";
    
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO "milan@walkonthetechside.com";
    ```
3. **Authenticate against your Azure subscription**:
    ```sh
    az login
    ```
    Please use the Entra User from above (in my case milan@walkonthetechside.com) and login to your subscription from your VS Code.

4. **Build API**:
    ```sh
    dotnet build
    ```

5. **Run the API**:
    ```sh
    dotnet run
    ```

6. **Test the API**:
    Open your browser or Postman and navigate to `http://localhost:5289/swagger/index.html` to test the API endpoints.

With these steps, you should be able to run the API locally without exposing passwords in the connection string.
![Demo Image](https://github.com/bbmilan/mui-postgresql/blob/main/imgs/Img-7.png)


Congratulations, you web API is connecting to Azure PostgreSQL database on Flexible Server without password in your local environment.

### Option 2: Deploying and running your web API on Azure

For this workload to run properly on Azure, we need to ensure that the user assigned managed identity that we created and assigned to the Azure Web Apphas has the right permissions to perform required operations on our schema in the todo_db database on Azure PostgreSQL Flexible Server.

1. **Login as a PostgreSQL Admin and run the follwoing**:
    ```sh
    GRANT USAGE, CREATE ON SCHEMA todoschema TO "aad_postgresql_988c7";

    GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE todoschema."Todo" TO "aad_postgresql_988c7";
    
    GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA todoschema TO "aad_postgresql_988c7";
    ```

2. **Deploy your API to Azure Web App. This can be achieved in many ways - for testing / PoC purposes, you may do it directly from VS Code**.

3. **Test the API**:
    Open your browser or Postman and navigate to `https://papayaukwebapp.azurewebsites.net/swagger/index.html` to test the API endpoints.

    With these steps, you should be able to run the API on Azure without exposing passwords in the connection string.

![Demo Image](https://github.com/bbmilan/mui-postgresql/blob/main/imgs/Img-8.png)



    
Congratulations, you web API is connecting to Azure PostgreSQL database on Flexible Server without password in your Azure environment.

