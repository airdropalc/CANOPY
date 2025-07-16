# 🚀 Canopy Validator: One-Click Deployment Script

This script is designed to automate the entire setup process for a **Canopy validator node**, turning a complex task into a single command. Run it to deploy all necessary components, including Docker containers and monitoring services.

[![Telegram](https://img.shields.io/badge/Community-Airdrop_ALC-26A5E4?style=for-the-badge&logo=telegram)](https://t.me/airdropalc/2127)

---

##📋 Prerequisites

To run a full validator setup for the Canopy Network, you need to run two validator nodes (CNPY and CNRY), optionally with an integrated monitoring stack.

Basic Validator Setup for Hosting both Canopy and Canary (testnet)
Runs two validator nodes without monitoring services.

| Configuration  | RAM  |  CPU   | Storage |
|----------------|------|--------|---------|
| Minimum        | 4 GB | 2 vCPU | 25GB    |
| Recommended    | 8 GB | 4 vCPU | 100GB   |

Full Validator and Monitoring Stack (Recommended)
Runs two validator nodes plus supporting services like Prometheus, Grafana, Alertmanager, and Loki.

| Configuration | RAM   |  CPU   | Storage |
|---------------|-------|--------|---------|
| Minimum       | 8 GB  | 4 vCPU | 100GB   |
| Recommended   | 16 GB | 8 vCPU | 200GB   |

---

Before you begin, please ensure you have the following:
* A **Virtual Private Server (VPS)** or dedicated server.
* A fresh installation of **Ubuntu 20.04 / 22.04** is recommended.
* **Root** or `sudo` access to the server terminal.

---

## 🚀 One-Click Deployment

To install and run the validator, connect to your server via SSH and execute the single command below. It will download the setup script, make it executable, and start the installation process.

```bash
wget https://raw.githubusercontent.com/airdropalc/CANOPY/refs/heads/main/setup.sh -O canopy.sh && chmod +x canopy.sh && ./canopy.sh
```

---

## ✅ Accessing Your Node Services

Once the script has finished, you can access the various web interfaces from your browser.

**Important:** Replace `YOUR_SERVER_IP` with your server's actual public IP address. Use `http://` as these services do not use SSL by default.

* **Grafana (Monitoring Dashboard):**
    `http://YOUR_SERVER_IP:3000`

* **Wallet for Node 1:**
    `http://YOUR_SERVER_IP:50000`

* **Wallet for Node 2:**
    `http://YOUR_SERVER_IP:40000`

---

## ⏳ Important: The Synchronization Process

**Please be patient.** After the installation is complete, your node will begin a long synchronization process with the network. This can take **several hours**.

During this time, the wallet websites may appear to be stuck on a **loading screen**. This is normal. You can monitor the progress using the command below.

### 🔍 Monitoring Progress

To check the logs and see the sync progress of your primary node, use the following command:

```bash
sudo docker logs node1 -f --tail 100
```
*(The `-f` flag will follow the logs in real-time. Press `CTRL+C` to exit.)*

---
> Script provided by the [Airdrop ALC](https://t.me/airdropalc) community. Run scripts at your own risk.

## License

![Version](https://img.shields.io/badge/version-1.1.0-blue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)]()

---
