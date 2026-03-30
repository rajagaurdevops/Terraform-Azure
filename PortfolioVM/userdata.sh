#!/bin/bash
set -ex

exec > >(tee /var/log/userdata.log) 2>&1

echo "===== 🚀 Starting deployment at $(date) ====="

########################################
# Update system
########################################
apt-get update 
apt-get upgrade -y

########################################
# Install dependencies
########################################
apt-get install -y curl git nginx

########################################
# Install Node.js (LTS)
########################################
# Wait for any existing dpkg processes to complete
echo "⏳ Waiting for dpkg lock to be released..."
while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1; do
    echo "dpkg process running, waiting..."
    sleep 5
done

# Clean up any stale locks
sudo rm -f /var/lib/dpkg/lock-frontend /var/lib/dpkg/lock /var/cache/apt/archives/lock

# Update package lists
apt-get update

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs

node -v
npm -v

########################################
# Install PM2
########################################
npm install -g pm2

########################################
# Setup app directory
########################################
cd /home/azureuser

# Ensure correct ownership (VERY IMPORTANT)
chown -R azureuser:azureuser /home/azureuser

# Clean old deploy
rm -rf portfolio

########################################
# Clone repo
########################################
echo "📥 Cloning repo..."

REPO_URL="dev.azure.com/rajagaur333/Devops_Learning/_git/portfolio"
USERNAME="rajagaur333"
PAT_TOKEN="${PAT_TOKEN}"

git clone https://${USERNAME}:${PAT_TOKEN}@dev.azure.com/rajagaur333/Devops_Learning/_git/portfolio

cd portfolio

########################################
# Install & Build
########################################
echo "📦 Installing dependencies..."
npm install

echo "🔨 Building app..."
npm run build

########################################
# Start app (CLUSTER MODE 🚀)
########################################
echo "🚀 Starting app with PM2 (cluster mode)..."

pm2 delete portfolio || true

pm2 start npm \
  --name "portfolio" \
  -i max \
  -- start

pm2 save

########################################
# Enable PM2 on startup (FIXED ✅)
########################################
echo "⚙️ Enabling PM2 startup..."

sudo env PATH=$PATH:/usr/bin \
/usr/lib/node_modules/pm2/bin/pm2 startup systemd \
-u azureuser --hp /home/azureuser

systemctl enable pm2-azureuser

########################################
# Nginx config
########################################
echo "🌐 Configuring Nginx..."

cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

########################################
# Restart Nginx
########################################
nginx -t
systemctl restart nginx
systemctl enable nginx

########################################
# Install Certbot (SSL)
########################################
apt-get install -y certbot python3-certbot-nginx

########################################
# Wait for DNS (important)
########################################
DOMAIN="test.vishnugaur.in"
EMAIL="nishanttdevops@gmail.com"

PUBLIC_IP=$(curl -s ifconfig.me)

echo "🌐 Waiting for DNS..."

until dig +short $DOMAIN | grep -q "$PUBLIC_IP"; do
  echo "DNS not ready yet..."
  sleep 15
done

########################################
# Setup SSL
########################################
certbot --nginx \
  -d $DOMAIN \
  --agree-tos \
  -m $EMAIL \
  --redirect \
  --non-interactive || true

########################################
# Enable auto-renew
########################################
systemctl enable certbot.timer
systemctl start certbot.timer

########################################
# Final status
########################################
pm2 status
systemctl status nginx --no-pager

echo "===== ✅ Deployment completed at $(date) ====="
echo "🌐 App running on: http://<YOUR_PUBLIC_IP>"
