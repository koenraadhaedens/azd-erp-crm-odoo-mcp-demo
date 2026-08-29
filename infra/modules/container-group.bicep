@description('Name of the azd environment.')
param environmentName string

@description('Azure region for the container group.')
param location string

@description('Tags applied to the container group.')
param tags object

@description('External ACR pull username.')
param containerRegistryUsername string

@secure()
@description('External ACR pull password or token.')
param containerRegistryPassword string

param odooImage string
param postgresImage string
param mcpImage string
param caddyImage string
param odooModules string
param mcpPort int

@secure()
param postgresPassword string

@secure()
param odooMasterPassword string

@secure()
param odooAdminPassword string

@secure()
param mcpApiKey string

var registryServer = 'acrdefcontainer.azurecr.io'
var postgresDatabase = 'odoo_demo'
var postgresUser = 'odoo'
var odooAdminLogin = 'admin'
var dnsNameLabel = 'odoo-${uniqueString(subscription().id, resourceGroup().id, environmentName)}'
var containerGroupFqdn = '${dnsNameLabel}.${location}.azurecontainer.io'

// The bootstrap container waits for PostgreSQL, initializes Odoo with demo data,
// rotates the admin credential, and releases the web process through an emptyDir marker.
var bootstrapScript = '''
set -eu
echo "Waiting for PostgreSQL..."
python3 - <<'PY'
import socket
import time

for attempt in range(120):
    try:
        with socket.create_connection(("127.0.0.1", 5432), timeout=2):
            print("PostgreSQL is accepting connections")
            break
    except OSError:
        time.sleep(2)
else:
    raise SystemExit("PostgreSQL did not become ready in time")
PY

odoo \
  --db_host=127.0.0.1 \
  --db_port=5432 \
  --db_user="$POSTGRES_USER" \
  --db_password="$POSTGRES_PASSWORD" \
  --admin-passwd="$ODOO_MASTER_PASSWORD" \
  --database="$POSTGRES_DB" \
  --init="$ODOO_MODULES" \
  --stop-after-init

printf "env.ref('base.user_admin').write({'login': '$ODOO_ADMIN_LOGIN', 'password': '$ODOO_ADMIN_PASSWORD'})\n" | odoo shell \
  --db_host=127.0.0.1 \
  --db_port=5432 \
  --db_user="$POSTGRES_USER" \
  --db_password="$POSTGRES_PASSWORD" \
  --database="$POSTGRES_DB"

touch /bootstrap/ready
echo "Odoo demo database is initialized"
'''

var odooStartScript = '''
set -eu
echo "Waiting for the Odoo bootstrap container..."
while [ ! -f /bootstrap/ready ]; do sleep 2; done
exec odoo \
  --db_host=127.0.0.1 \
  --db_port=5432 \
  --db_user="$POSTGRES_USER" \
  --db_password="$POSTGRES_PASSWORD" \
  --admin-passwd="$ODOO_MASTER_PASSWORD" \
  --database="$POSTGRES_DB" \
  --db-filter="^$POSTGRES_DB$" \
  --proxy-mode
'''

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2026-07-01' = {
  name: 'aci-${environmentName}'
  location: location
  tags: union(tags, {
    'azd-service-name': 'odoo-mcp'
  })
  properties: {
    osType: 'Linux'
    restartPolicy: 'OnFailure'
    imageRegistryCredentials: [
      {
        server: registryServer
        username: containerRegistryUsername
        password: containerRegistryPassword
      }
    ]
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnsNameLabel
      ports: [
        {
          port: 80
          protocol: 'TCP'
        }
        {
          port: 443
          protocol: 'TCP'
        }
      ]
    }
    volumes: [
      {
        name: 'postgres-data'
        emptyDir: {}
      }
      {
        name: 'bootstrap-state'
        emptyDir: {}
      }
      {
        name: 'caddy-data'
        emptyDir: {}
      }
      {
        name: 'caddy-config'
        emptyDir: {}
      }
    ]
    containers: [
      {
        name: 'postgres'
        properties: {
          image: postgresImage
          ports: [
            {
              port: 5432
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'POSTGRES_DB'
              value: postgresDatabase
            }
            {
              name: 'POSTGRES_USER'
              value: postgresUser
            }
            {
              name: 'POSTGRES_PASSWORD'
              secureValue: postgresPassword
            }
            {
              name: 'PGDATA'
              value: '/var/lib/postgresql/data/pgdata'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          volumeMounts: [
            {
              name: 'postgres-data'
              mountPath: '/var/lib/postgresql/data'
            }
          ]
        }
      }
      {
        name: 'odoo-bootstrap'
        properties: {
          image: odooImage
          command: [
            '/bin/bash'
            '-c'
            bootstrapScript
          ]
          environmentVariables: [
            {
              name: 'POSTGRES_DB'
              value: postgresDatabase
            }
            {
              name: 'POSTGRES_USER'
              value: postgresUser
            }
            {
              name: 'POSTGRES_PASSWORD'
              secureValue: postgresPassword
            }
            {
              name: 'ODOO_MASTER_PASSWORD'
              secureValue: odooMasterPassword
            }
            {
              name: 'ODOO_ADMIN_LOGIN'
              value: odooAdminLogin
            }
            {
              name: 'ODOO_ADMIN_PASSWORD'
              secureValue: odooAdminPassword
            }
            {
              name: 'ODOO_MODULES'
              value: odooModules
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          volumeMounts: [
            {
              name: 'bootstrap-state'
              mountPath: '/bootstrap'
            }
          ]
        }
      }
      {
        name: 'odoo'
        properties: {
          image: odooImage
          command: [
            '/bin/bash'
            '-c'
            odooStartScript
          ]
          ports: [
            {
              port: 8069
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'POSTGRES_DB'
              value: postgresDatabase
            }
            {
              name: 'POSTGRES_USER'
              value: postgresUser
            }
            {
              name: 'POSTGRES_PASSWORD'
              secureValue: postgresPassword
            }
            {
              name: 'ODOO_MASTER_PASSWORD'
              secureValue: odooMasterPassword
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 2
            }
          }
          volumeMounts: [
            {
              name: 'bootstrap-state'
              mountPath: '/bootstrap'
            }
          ]
        }
      }
      {
        name: 'mcp-server'
        properties: {
          image: mcpImage
          ports: [
            {
              port: mcpPort
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'PORT'
              value: string(mcpPort)
            }
            {
              name: 'MCP_PORT'
              value: string(mcpPort)
            }
            {
              name: 'ODOO_URL'
              value: 'http://127.0.0.1:8069'
            }
            {
              name: 'ODOO_DB'
              value: postgresDatabase
            }
            {
              name: 'ODOO_DATABASE'
              value: postgresDatabase
            }
            {
              name: 'ODOO_USERNAME'
              value: odooAdminLogin
            }
            {
              name: 'ODOO_PASSWORD'
              secureValue: odooAdminPassword
            }
            {
              name: 'MCP_API_KEY'
              secureValue: mcpApiKey
            }
            {
              name: 'MCP_ALLOWED_HOSTS'
              value: '${containerGroupFqdn},${containerGroupFqdn}:*,localhost,localhost:*,127.0.0.1,127.0.0.1:*'
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
        }
      }
      {
        name: 'caddy'
        properties: {
          image: caddyImage
          ports: [
            {
              port: 80
              protocol: 'TCP'
            }
            {
              port: 443
              protocol: 'TCP'
            }
          ]
          environmentVariables: [
            {
              name: 'PUBLIC_FQDN'
              value: containerGroupFqdn
            }
          ]
          resources: {
            requests: {
              cpu: 1
              memoryInGB: 1
            }
          }
          volumeMounts: [
            {
              name: 'caddy-data'
              mountPath: '/data'
            }
            {
              name: 'caddy-config'
              mountPath: '/config'
            }
          ]
        }
      }
    ]
  }
}

output containerGroupName string = containerGroup.name
output containerGroupId string = containerGroup.id
output fqdn string = containerGroup.properties.ipAddress.fqdn
output odooUrl string = 'https://${containerGroup.properties.ipAddress.fqdn}'
output mcpUrl string = 'https://${containerGroup.properties.ipAddress.fqdn}/mcp'
output odooDatabase string = postgresDatabase
output odooAdminLogin string = odooAdminLogin
