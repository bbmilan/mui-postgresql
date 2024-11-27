# Variables
SUBSCRIPTION_ID="2a231c16-ff3a-4bea-91ec-7ce843a98650"
RESOURCE_GROUP="mui-onefineday-rg"
APP_SERVICE_PLAN="primerspplan"  
WEBAPP_NAME="papayaukwebapp"  
LOCATION="uksouth"

# PostgreSQL variables
POSTGRES_SERVER_NAME="papajaukserver"  
POSTGRES_ADMIN_USER="milanju"
POSTGRES_ADMIN_PASSWORD="SecurePassword123!"   
POSTGRES_DATABASE_NAME="todo_db"
POSTGRES_SKU_NAME="Standard_B1ms"
POSTGRES_VERSION="16"
POSTGRES_ENTRA_ADMIN="milan@walkonthetechside.com"
POSTGRES_ENTRA_ADMIN_OBJECT_ID="a0175e74-5fb6-400d-962a-e06288111863"

# User-assigned managed identity variables
MANAGED_IDENTITY_NAME="papayaukwebapp-mi"
MANAGED_IDENTITY_LOCATION="uksouth"

# Create Resource Group
az group create --name $RESOURCE_GROUP --location $LOCATION

# Create App Service Plan
az appservice plan create --name $APP_SERVICE_PLAN --resource-group $RESOURCE_GROUP --sku P0V3 --is-linux

# Create Web App
az webapp create --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --plan $APP_SERVICE_PLAN --runtime "DOTNETCORE:8.0"

# Create PostgreSQL Flexible Server
az postgres flexible-server create \
  --name $POSTGRES_SERVER_NAME \
  --resource-group $RESOURCE_GROUP \
  --location $LOCATION \
  --admin-user $POSTGRES_ADMIN_USER \
  --admin-password $POSTGRES_ADMIN_PASSWORD \
  --sku-name $POSTGRES_SKU_NAME \
  --tier Burstable \
  --active-directory-auth Enabled \
  --version $POSTGRES_VERSION \
  --storage-size 32 \
  --public-access 0.0.0.0

# Create a Microsoft Entra Admin for the PostgreSQL Server
az postgres flexible-server ad-admin create \
    --resource-group $RESOURCE_GROUP \
    --server-name $POSTGRES_SERVER_NAME \
    --display-name $POSTGRES_ENTRA_ADMIN \
    --object-id $POSTGRES_ENTRA_ADMIN_OBJECT_ID \
    --type User

# Create PostgreSQL Database
az postgres flexible-server db create \
  --resource-group $RESOURCE_GROUP \
  --server-name $POSTGRES_SERVER_NAME \
  --database-name $POSTGRES_DATABASE_NAME

# Configure Firewall Rule to Allow Azure Services Access
az postgres flexible-server firewall-rule create \
  --resource-group $RESOURCE_GROUP \
  --name $POSTGRES_SERVER_NAME \
  --rule-name "allowconnections" \
  --start-ip-address 0.0.0.0 \
  --end-ip-address 255.255.255.255

# # Get the connection string
# CONNECTION_STRING="Host=${POSTGRES_SERVER_NAME}.postgres.database.azure.com;Database=${POSTGRES_DATABASE_NAME};Port=5432;User Id=${POSTGRES_ADMIN_USER};Password=${POSTGRES_ADMIN_PASSWORD};Ssl Mode=Require;"

# Create a user-assigned managed identity
# MANAGED_IDENTITY_ID=$(az identity create --name "$MANAGED_IDENTITY_NAME" --resource-group "$RESOURCE_GROUP" --location "$MANAGED_IDENTITY_LOCATION" --query 'id' -o tsv)

# Create the user-assigned managed identity and capture its resource ID and client ID
read MANAGED_IDENTITY_ID MANAGED_IDENTITY_CLIENT_ID <<< $(az identity create \
  --name "$MANAGED_IDENTITY_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --location "$MANAGED_IDENTITY_LOCATION" \
  --query '[id, clientId]' \
  -o tsv)

# Verify that the variables are set correctly
# echo "Managed Identity ID: $MANAGED_IDENTITY_ID"
# echo "Managed Identity Client ID: $MANAGED_IDENTITY_CLIENT_ID"

# #Assign the managed identity to the web app
az webapp identity assign --name $WEBAPP_NAME --resource-group $RESOURCE_GROUP --identities $MANAGED_IDENTITY_ID


az extension add --name serviceconnector-passwordless --upgrade

az webapp connection create postgres-flexible --connection postgresql_988c7 \
 --source-id /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.Web/sites/$WEBAPP_NAME \
 --target-id /subscriptions/$SUBSCRIPTION_ID/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.DBforPostgreSQL/flexibleServers/$POSTGRES_SERVER_NAME/databases/$POSTGRES_DATABASE_NAME \
 --client-type dotnet \
 --user-identity client-id=$MANAGED_IDENTITY_CLIENT_ID subs-id=$SUBSCRIPTION_ID


