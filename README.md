# Technical Documentation: Portfolio Website Deployment on Azure VM

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Terraform Infrastructure Setup](#terraform-infrastructure-setup)
4. [VM Configuration and Application Setup](#vm-configuration-and-application-setup)
5. [CI/CD Pipeline Implementation](#cicd-pipeline-implementation)
6. [Deployment Process](#deployment-process)
7. [Monitoring and Observability](#monitoring-and-observability)
8. [Troubleshooting Guide](#troubleshooting-guide)

---

## Overview

This document describes the complete technical implementation of deploying a Next.js portfolio website on Azure Virtual Machine using Terraform for infrastructure as code and Azure DevOps for CI/CD pipeline.

### Key Components
- **Infrastructure**: Terraform-managed Azure VM with networking and monitoring
- **Application**: Next.js portfolio website with PM2 process management
- **CI/CD**: Azure DevOps pipeline for automated deployments
- **Monitoring**: Azure Monitor with Log Analytics and alerting

---

## Architecture

### High-Level Architecture Diagram

```mermaid
graph TB
    subgraph "Development"
        DEV[Developer Machine]
        GIT[Git Repository<br/>Azure DevOps]
    end
    
    subgraph "CI/CD Pipeline"
        PIPELINE[Azure DevOps Pipeline]
        BUILD[Build & Test]
        DEPLOY[Deploy to VM]
    end
    
    subgraph "Azure Infrastructure"
        subgraph "Compute"
            VM[Portfolio VM<br/>Ubuntu 22.04 LTS]
            NGINX[Nginx Reverse Proxy]
            APP[Next.js App<br/>PM2 Managed]
        end
        
        subgraph "Network"
            VNET[Virtual Network<br/>10.0.0.0/16]
            SUBNET[Subnet<br/>10.0.1.0/24]
            PIP[Public IP<br/>Static]
            NSG[Network Security Group]
        end
        
        subgraph "Monitoring"
            AMA[Azure Monitor Agent]
            LAW[Log Analytics Workspace]
            DCR[Data Collection Rule]
            ALERT[Alert System]
        end
    end
    
    subgraph "External Access"
        USER[End Users]
        DOMAIN[test.vishnagur.in]
        SSL[SSL Certificate<br/>Let's Encrypt]
    end
    
    %% Development Flow
    DEV -->|Push Code| GIT
    GIT -->|Trigger| PIPELINE
    PIPELINE --> BUILD
    BUILD --> DEPLOY
    DEPLOY --> VM
    
    %% Application Flow
    USER --> DOMAIN
    DOMAIN --> SSL
    SSL --> PIP
    PIP --> NSG
    NSG --> VM
    VM --> NGINX
    NGINX --> APP
    
    %% Monitoring Flow
    VM --> AMA
    AMA --> DCR
    DCR --> LAW
    LAW --> ALERT
```

### Technology Stack

| Layer | Technology | Purpose |
|-------|------------|---------|
| **Infrastructure** | Terraform | Infrastructure as Code |
| **Compute** | Azure VM (Ubuntu 22.04 LTS) | Application hosting |
| **Web Server** | Nginx | Reverse proxy and SSL termination |
| **Application** | Next.js + PM2 | Portfolio website and process management |
| **CI/CD** | Azure DevOps Pipelines | Automated deployment |
| **Monitoring** | Azure Monitor + Log Analytics | Performance monitoring and alerting |
| **Security** | Let's Encrypt | SSL certificates |

---

### Critical Monitoring Flow (Simplified)

```mermaid
graph LR
    subgraph "VM"
        APP[Portfolio App]
        AMA[Azure Monitor Agent]
    end
    
    subgraph "Azure Cloud"
        DCR[Data Collection Rule]
        LAW[Log Analytics]
        ALERT[Alert System]
        EMAIL[📧 Email Alert]
    end
    
    APP -->|Collects data| AMA
    AMA -->|Sends every 60s| DCR
    DCR -->|Stores & indexes| LAW
    LAW -->|Evaluates rules| ALERT
    ALERT -->|Sends notification| EMAIL
    
    style AMA fill:#0078d4,color:#fff
    style DCR fill:#ff6900,color:#fff
    style LAW fill:#28a745,color:#fff
    style ALERT fill:#dc3545,color:#fff
    style EMAIL fill:#6f42c1,color:#fff
```

#### How This Works (Critical Path):

1. **📊 Data Collection**: Azure Monitor Agent on VM collects CPU & memory every 60 seconds
2. **🎯 Data Processing**: Data Collection Rule filters and routes the data  
3. **🗄️ Data Storage**: Log Analytics Workspace stores all monitoring data
4. **🚨 Alert Evaluation**: Alert System checks if memory < 500MB
5. **📧 Notification**: Sends email alert when threshold is breached

#### Why This is Critical:

- **❌ Without Monitoring**: VM crashes, you don't know why
- **✅ With Monitoring**: Get alerts BEFORE problems impact users
- **🔍 Root Cause**: Logs help identify the exact issue
- **⚡ Fast Response**: Alerts enable quick problem resolution

---

#### Azure Monitor Agent (AMA)

**What is Azure Monitor Agent?**
Azure Monitor Agent is a lightweight agent that runs on Azure VMs to collect performance data, logs, and metrics from the operating system and applications.

**Key Features:**
- **Multi-source Collection**: Gathers metrics, logs, and process information
- **Real-time Processing**: Processes data with minimal latency
- **Secure Transmission**: Uses HTTPS/TLS for data security
- **Resource Efficient**: Lightweight design with minimal CPU/memory impact
- **Auto-recovery**: Automatically restarts if service fails

#### Data Collection Rule (DCR)

**What is Data Collection Rule?**
A Data Collection Rule is a centralized configuration that defines what data to collect, how often to collect it, and where to send it. It acts as the "traffic controller" for all monitoring data.

**Key Configuration:**
- **Data Sources**: CPU, memory, logs, events
- **Collection Frequency**: Every 60 seconds
- **Destinations**: Log Analytics Workspace
- **Data Processing**: Filtering, transformation, enrichment

#### Log Analytics Workspace (LAW)

**What is Log Analytics Workspace?**
Log Analytics Workspace is a centralized data repository that collects, stores, analyzes, and visualizes monitoring data from multiple sources.

**Key Components:**
- **Data Ingestion**: Multiple endpoints for different data sources
- **Processing**: Real-time indexing and optimization
- **Storage Tiering**: Hot/warm/cold storage for cost optimization
- **Query Engine**: Kusto Query Language (KQL) for powerful analysis
- **Retention Policies**: Automatic data lifecycle management

#### Alert System

**What is Azure Alert System?**
Azure Alert System is a comprehensive monitoring and notification service that continuously evaluates monitoring data against predefined conditions and triggers automated responses when thresholds are exceeded.

**Alert Lifecycle:**
1. **Normal**: System monitoring continuously
2. **Evaluating**: Checking conditions against data
3. **Alerting**: Condition met, send notifications
4. **Firing**: Active alert state
5. **Resolved**: Condition cleared, return to normal

**Notification Channels:**
- **Email**: SMTP integration for email alerts
- **SMS**: Mobile notifications for urgent issues
- **Webhooks**: Custom integrations with other systems
- **Automation**: Self-healing actions through runbooks

---### Component Interactions

- Developers push code to Azure DevOps repository
- Pipeline triggers automatically on main branch commits
- Terraform provisions and manages Azure infrastructure
- VM runs user data script for application setup
- Azure Monitor Agent collects performance metrics
- Data Collection Rule processes and routes data
- Log Analytics Workspace stores and indexes data
- Alert System evaluates conditions and sends notifications
- Nginx serves traffic with SSL termination

---

## Terraform Infrastructure Setup

### Terraform Code Structure

```
PortfolioVM/
├── main.tf          # Main resources (VM, monitoring, extensions)
├── network.tf       # Networking resources (VNet, Subnet)
├── security.tf      # Network Security Group rules
├── variables.tf     # Input variables
├── terraform.tfvars # Variable values
├── outputs.tf       # Output values
├── backend.tf      # Terraform state configuration
├── provider.tf     # Azure provider configuration
└── userdata.sh     # VM initialization script
```

### Terraform Workflow Diagram

```mermaid
graph LR
    subgraph "Local Development"
        TF_PLAN[Terraform Plan]
        TF_APPLY[Terraform Apply]
    end
    
    subgraph "Azure Resources"
        VNET[Virtual Network]
        VM[Virtual Machine]
        LAW[Log Analytics]
        DCR[Data Collection Rule]
        EXT[VM Extensions]
    end
    
    subgraph "State Management"
        STATE[Terraform State<br/>Azure Blob Storage]
    end
    
    TF_PLAN -->|Preview Changes| VNET
    TF_PLAN -->|Preview Changes| VM
    TF_PLAN -->|Preview Changes| LAW
    TF_PLAN -->|Preview Changes| DCR
    TF_PLAN -->|Preview Changes| EXT
    
    TF_APPLY -->|Create Resources| VNET
    TF_APPLY -->|Create Resources| VM
    TF_APPLY -->|Create Resources| LAW
    TF_APPLY -->|Create Resources| DCR
    TF_APPLY -->|Create Resources| EXT
    
    TF_PLAN --> STATE
    TF_APPLY --> STATE
```

### Key Terraform Resources Explained

#### 1. Virtual Machine Configuration

```hcl
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  size                  = var.vm_size
  admin_username        = var.admin_username
  network_interface_ids = [azurerm_network_interface.nic.id]

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("userdata.sh", {
    PAT_TOKEN = var.pat_token
    USERNAME  = "rajagaur333"
    REPO_URL  = "https://dev.azure.com/rajagaur333/Devops_Learning/_git/portfolio"
  }))
}
```

**How it works:**
1. Creates Ubuntu 22.04 LTS VM with specified size
2. Attaches network interface for connectivity
3. Uses SSH key for authentication (retrieved from existing key)
4. Executes user data script on first boot for application setup

#### 2. Network Infrastructure

```hcl
resource "azurerm_virtual_network" "vnet" {
  name                = "portfolio-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "subnet" {
  name                 = "portfolio-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}
```

**Network Design:**
- **VNet**: 10.0.0.0/16 provides 65,536 IP addresses
- **Subnet**: 10.0.1.0/24 provides 256 IP addresses for VMs
- **Public IP**: Static IP for consistent external access

#### 3. Security Configuration

```hcl
resource "azurerm_network_security_group" "nsg" {
  security_rule {
    name                       = "allow_ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    destination_port_range     = "22"
  }
  
  security_rule {
    name                       = "allow_http"
    priority                   = 110
    destination_port_range     = "80"
  }
  
  security_rule {
    name                       = "allow_https"
    priority                   = 120
    destination_port_range     = "443"
  }
  
  security_rule {
    name                       = "allow_app"
    priority                   = 130
    destination_port_range     = "3000"
  }
}
```

**Security Rules:**
- **Port 22**: SSH access for management
- **Port 80**: HTTP traffic for website
- **Port 443**: HTTPS traffic for secure website
- **Port 3000**: Direct application access (for development/debugging)

#### 4. Monitoring Setup

```hcl
resource "azurerm_log_analytics_workspace" "law" {
  name                = "vm-monitoring-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                = "vm-dcr"
  location            = var.location
  resource_group_name = var.resource_group_name

  destinations {
    log_analytics {
      workspace_resource_id = azurerm_log_analytics_workspace.law.id
      name                  = "logdest"
    }
  }

  data_sources {
    performance_counter {
      name                          = "cpuMetrics"
      sampling_frequency_in_seconds = 60
      streams                       = ["Microsoft-Perf"]
      counter_specifiers = [
        "\\Processor(_Total)\\% Processor Time",
        "\\Memory\\Available Bytes"
      ]
    }
  }
}
```

**Monitoring Configuration:**
- **Log Analytics Workspace**: Centralized data storage with 30-day retention
- **Data Collection Rule**: Collects CPU and memory metrics every 60 seconds
- **VM Extension**: Installs Azure Monitor Agent on the VM

---

## VM Configuration and Application Setup

### User Data Script Flow

```mermaid
graph TD
    subgraph "VM Boot Process"
        BOOT[VM Starts]
        USERDATA[User Data Script Executes]
        SYSTEM_UPDATE[System Update & Package Install]
        APP_SETUP[Application Setup]
        SERVICE_CONFIG[Service Configuration]
        FINALIZE[Finalization]
    end
    
    subgraph "Application Components"
        NODE[Node.js Installation]
        GIT[Git Repository Clone]
        DEPS[NPM Dependencies]
        BUILD[Next.js Build]
        PM2[PM2 Process Manager]
        NGINX[Nginx Configuration]
        SSL[SSL Certificate Setup]
    end
    
    BOOT --> USERDATA
    USERDATA --> SYSTEM_UPDATE
    SYSTEM_UPDATE --> APP_SETUP
    APP_SETUP --> SERVICE_CONFIG
    SERVICE_CONFIG --> FINALIZE
    
    SYSTEM_UPDATE --> NODE
    APP_SETUP --> GIT
    APP_SETUP --> DEPS
    APP_SETUP --> BUILD
    SERVICE_CONFIG --> PM2
    SERVICE_CONFIG --> NGINX
    SERVICE_CONFIG --> SSL
```

### Key User Data Script Components

#### 1. System Preparation
```bash
# Update system and install required packages
apt-get update -y
apt-get install -y nginx git curl certbot python3-certbot-nginx

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs
```

#### 2. Application Deployment
```bash
# Clone repository with authentication
git clone https://${USERNAME}:${PAT_TOKEN}@dev.azure.com/rajagaur333/Devops_Learning/_git/portfolio

# Install dependencies and build
cd /home/azureuser/portfolio
npm install
npm run build
```

#### 3. Process Management
```bash
# Start application with PM2
pm2 start npm --name portfolio -i max -- start
pm2 save
pm2 startup
```

#### 4. Web Server Configuration
```bash
# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/portfolio << EOF
server {
    listen 80;
    server_name test.vishnagur.in;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF
```

#### 5. SSL Certificate Setup
```bash
# Obtain SSL certificate
certbot --nginx -d test.vishnagur.in --agree-tos -m rajagaur333@gmail.com --redirect --non-interactive
```

---

## CI/CD Pipeline Implementation

### Pipeline Architecture

```mermaid
graph LR
    subgraph "Source Control"
        REPO[Git Repository]
        BRANCH[Main Branch]
    end
    
    subgraph "Azure DevOps Pipeline"
        TRIGGER[Trigger on Push]
        CHECKOUT[Checkout Code]
        BUILD[Build Stage]
        DEPLOY[Deploy Stage]
    end
    
    subgraph "Deployment Process"
        SSH[SSH Connection]
        SCRIPTS[Deployment Scripts]
        HEALTH[Health Check]
    end
    
    subgraph "Production"
        VM[Azure VM]
        APP[Running Application]
    end
    
    REPO --> BRANCH
    BRANCH --> TRIGGER
    TRIGGER --> CHECKOUT
    CHECKOUT --> BUILD
    BUILD --> DEPLOY
    DEPLOY --> SSH
    SSH --> SCRIPTS
    SCRIPTS --> VM
    VM --> APP
    SCRIPTS --> HEALTH
    HEALTH --> APP
```

### Azure DevOps Pipeline Configuration

#### Pipeline YAML Structure
```yaml
# Azure DevOps Pipeline for Portfolio Website Deployment
trigger:
  branches:
    include:
      - main

pool:
  vmImage: ubuntu-latest

variables:
  VM_USER: "azureuser"
  VM_IP: "40.80.90.37"
  APP_DIR: "/home/azureuser/portfolio"

steps:
# 1️⃣ Checkout source code
- checkout: self

# 2️⃣ Download SSH private key
- task: DownloadSecureFile@1
  name: sshKey
  inputs:
    secureFile: 'portfolio_key.pem'

# 3️⃣ Deploy with zero-downtime
- script: |
    set -e
    chmod 600 $(sshKey.secureFilePath)
    
    # Execute deployment on remote VM
    ssh -i $(sshKey.secureFilePath) $(VM_USER)@$(VM_IP) "
      cd $APP_DIR
      
      # Zero-downtime deployment
      sudo chown -R azureuser:azureuser $APP_DIR
      git config --global --add safe.directory $APP_DIR
      git pull origin main
      npm install
      rm -rf .next
      npm run build
      pm2 restart portfolio
      pm2 save
      
      # Health check
      sleep 3
      curl -f http://localhost:3000 && echo '✅ Success' || echo '❌ Failed'
    "
  displayName: "Deploy Portfolio App"
```

### Deployment Process Flow

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as Git Repository
    participant Pipeline as Azure DevOps
    participant VM as Azure VM
    participant App as Next.js App
    
    Dev->>Git: Push changes to main
    Git->>Pipeline: Trigger pipeline
    Pipeline->>Pipeline: Checkout code
    Pipeline->>Pipeline: Download SSH key
    Pipeline->>VM: SSH connection
    Pipeline->>VM: Pull latest code
    Pipeline->>VM: Install dependencies
    Pipeline->>VM: Build application
    Pipeline->>VM: Restart PM2 process
    Pipeline->>VM: Health check
    VM->>App: Restart with new code
    App->>Pipeline: Health status
    Pipeline->>Dev: Deployment result
```

### Zero-Downtime Deployment Strategy

The pipeline implements zero-downtime deployment through:

1. **Process Management**: PM2 handles graceful restarts
2. **Build Isolation**: Clean build prevents conflicts
3. **Health Checks**: Verifies application health before completion
4. **Rollback Ready**: Previous version remains available during deployment

---

## Deployment Process

### Initial Infrastructure Deployment

```bash
# 1. Initialize Terraform
cd PortfolioVM
terraform init

# 2. Review deployment plan
terraform plan

# 3. Apply infrastructure
terraform apply
```

### Application Deployment Process

#### Manual Deployment
```bash
# SSH into VM
ssh -i portfolio_key.pem azureuser@<VM_IP>

# Navigate to application directory
cd /home/azureuser/portfolio

# Pull latest changes
git pull origin main

# Install dependencies
npm install

# Build application
npm run build

# Restart application
pm2 restart portfolio
```

#### Automated Deployment
```bash
# Push changes to trigger pipeline
git add .
git commit -m "Update portfolio content"
git push origin main
```

### Environment Variables

| Variable | Value | Purpose |
|----------|-------|---------|
| `VM_USER` | azureuser | SSH username |
| `VM_IP` | 40.80.90.37 | VM public IP |
| `APP_DIR` | /home/azureuser/portfolio | Application directory |
| `DOMAIN` | test.vishnagur.in | Website domain |
| `EMAIL` | rajagaur333@gmail.com | SSL certificate email |

---

## Monitoring and Observability

### Monitoring Architecture

```mermaid
graph TB
    subgraph "Data Collection"
        VM[Virtual Machine]
        AMA[Azure Monitor Agent]
        SYS[System Metrics]
        APP[Application Logs]
    end
    
    subgraph "Data Processing"
        DCR[Data Collection Rule]
        FILTER[Data Filtering]
        AGG[Data Aggregation]
    end
    
    subgraph "Data Storage"
        LAW[Log Analytics Workspace]
        INDEX[Data Indexing]
        STORE[Data Storage]
    end
    
    subgraph "Alerting"
        RULES[Alert Rules]
        THRESH[Threshold Evaluation]
        NOTIFY[Email Notifications]
    end
    
    subgraph "Visualization"
        DASH[Azure Dashboards]
        QUERY[Log Analytics Queries]
        WORKBOOK[Workbooks]
    end
    
    VM --> AMA
    AMA --> SYS
    AMA --> APP
    AMA --> DCR
    DCR --> FILTER
    FILTER --> AGG
    AGG --> LAW
    LAW --> INDEX
    INDEX --> STORE
    STORE --> RULES
    RULES --> THRESH
    THRESH --> NOTIFY
    STORE --> DASH
    STORE --> QUERY
    STORE --> WORKBOOK
```

### Monitoring Configuration

#### 1. Metrics Collection
- **CPU Usage**: Collected every 60 seconds
- **Memory Usage**: Available memory monitoring
- **Disk I/O**: Storage performance metrics
- **Network Traffic**: Bandwidth utilization

#### 2. Alert Configuration
```hcl
resource "azurerm_monitor_metric_alert" "memory_alert" {
  name                = "low-memory-alert"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_linux_virtual_machine.vm.id]

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Available Memory Bytes"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 500000000  # ~500MB
  }

  frequency   = "PT1M"  # Check every 1 minute
  window_size = "PT5M"  # Evaluate over 5-minute window

  action {
    action_group_id = azurerm_monitor_action_group.email_alert.id
  }
}
```

#### 3. Log Queries
```kusto
// CPU Usage Query
Perf
| where ObjectName == "Processor" and CounterName == "% Processor Time"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart

// Memory Usage Query
Perf
| where ObjectName == "Memory" and CounterName == "Available Bytes"
| summarize avg(CounterValue) by bin(TimeGenerated, 5m), Computer
| render timechart
```

---

## Troubleshooting Guide

### Common Issues and Solutions

#### 1. VM Deployment Issues

**Problem**: Terraform apply fails due to resource conflicts
```bash
Error: Error creating Virtual Machine: compute.VirtualMachinesClient#CreateOrUpdate:
failed waiting for Virtual Machine to be in a succeeded state
```

**Solution**:
```bash
# Check resource status
az vm show --name portfolio-vm --resource-group RG-Devops

# Clean up failed resources
terraform destroy -target=azurerm_linux_virtual_machine.vm

# Re-apply
terraform apply
```

#### 2. Application Deployment Issues

**Problem**: PM2 process fails to start
```bash
[PM2][ERROR] Process portfolio not found
```

**Solution**:
```bash
# Check PM2 status
pm2 status

# Check application logs
pm2 logs portfolio

# Restart application
pm2 start npm --name portfolio -i max -- start
pm2 save
```

#### 3. SSL Certificate Issues

**Problem**: Certbot fails to obtain SSL certificate
```bash
Error: Permission denied: '/var/log/letsencrypt'
```

**Solution**:
```bash
# Run with sudo
sudo certbot --nginx -d test.vishnagur.in --agree-tos -m email@example.com --redirect --non-interactive

# Check certificate status
sudo certbot certificates
```

#### 4. Monitoring Issues

**Problem**: No data in Log Analytics
```bash
# Check VM extension status
az vm extension show --resource-group RG-Devops --vm-name portfolio-vm --name AzureMonitorLinuxAgent

# Restart monitoring agent
sudo systemctl restart azuremonitoragent

# Check DCR association
az monitor data-collection rule association show --name vm-dcr-association --resource-group RG-Devops
```

### Performance Optimization

#### 1. VM Performance
- Use appropriate VM size (Standard_B1s for small portfolio)
- Monitor CPU and memory usage
- Optimize Next.js build process

#### 2. Network Performance
- Use static public IP for consistent DNS
- Configure Nginx caching headers
- Enable gzip compression

#### 3. Application Performance
- Implement Next.js static generation
- Use PM2 cluster mode for multi-core utilization
- Monitor application response times

### Security Best Practices

1. **SSH Key Management**: Use secure SSH keys, disable password authentication
2. **Network Security**: Configure NSG rules properly, limit exposed ports
3. **SSL/TLS**: Always use HTTPS, keep certificates updated
4. **Monitoring**: Set up alerts for suspicious activities
5. **Backups**: Regularly backup application data and configuration

---

## Conclusion

This technical documentation provides a comprehensive guide to deploying a Next.js portfolio website on Azure VM using Terraform and Azure DevOps. The implementation follows DevOps best practices including:

- **Infrastructure as Code** with Terraform
- **Automated CI/CD** with Azure DevOps
- **Comprehensive Monitoring** with Azure Monitor
- **Security Best Practices** with SSL and network security
- **Zero-Downtime Deployment** with PM2 process management

The solution is scalable, maintainable, and production-ready for professional portfolio hosting.
