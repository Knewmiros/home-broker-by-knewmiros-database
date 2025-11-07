# Railway Cron Job Configuration

# Add this to your Railway project

# railway.json or railway.toml

{
"build": {
"builder": "DOCKERFILE"
},
"deploy": {
"numReplicas": 1,
"restartPolicyType": "ON_FAILURE"
}
}

# To set up cron job in Railway:

# 1. Create a new service in Railway

# 2. Set it as a "Cron Job" type

# 3. Configure schedule: "0 2 \* \* \*" (2 AM daily)

# 4. Set command: "/app/backup-cron.sh"
