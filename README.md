# Futro S740 Kubernetes Cluster

![GitHub Template](https://img.shields.io/badge/template-repository-blue?style=flat-square)
![Terraform](https://img.shields.io/badge/terraform-%3E%3D1.5.0-623CE4?style=flat-square&logo=terraform)
![License](https://img.shields.io/github/license/bueckerlars/futro-S740-cluster?style=flat-square)
![GitHub stars](https://img.shields.io/github/stars/bueckerlars/futro-S740-cluster?style=flat-square)
![GitHub forks](https://img.shields.io/github/forks/bueckerlars/futro-S740-cluster?style=flat-square)

A high-availability Kubernetes cluster built using Fujitsu Futro S740 thin clients.

> **Template Repository**: This is a template repository. Click the "Use this template" button to create your own cluster setup based on this configuration.

## Overview

This project documents the setup and configuration of a Kubernetes cluster using Fujitsu Futro S740 devices as cluster nodes. Two configurations are supported: a high-availability setup with 3 control plane nodes and 1 worker, or a maximum capacity setup with 1 control plane node and 3 workers.

## Hardware List

The following hardware components are used in this setup:

> *Note*: The listed components are examples and can be adjusted to suit the specific needs of your cluster.

| Component                   | Description                                                     | Link                                                                                                              |
| --------------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| **Rack**                    | GeekPi Mini-Rack 8HE                                            | [Amazon](https://www.amazon.de/gp/product/B0FBFDZD4C?smid=A187Y4UVM6ZA0X)                                         |
| **Power Socket**            | 1 Gbit managed switch                                           | [Amazon](https://www.amazon.de/gp/product/B09M6W23ZM?smid=A3JWKAKR8XB7XF)                                         |
| **Gigabit Swith**           | TP-Link TL-SG608E 8-Port Gigabit Switch                         | [Amazon](https://www.amazon.de/gp/product/B0CLB34427)                                                             |
| **Network Patchpanel**      | GeeekPi 12 Port Patch Panel                                     | [Amazon](https://www.amazon.de/gp/product/B0D5Q6CJ1J?smid=A3JWKAKR8XB7XF)                                         |
| **Rack Mount (3D Printed)** | 1U rack mount with Keystone jacks for Futro S7                  | [Printables](https://www.printables.com/model/1371342-10-rack-mount-1u-w-keystone-jacks-fujitsu-futro-s7?lang=de) |
| **Futro S740 Nodes**        | Fujitsu Futro S740 J4105 Quad 1.5GHz 4GB 32GB (passive cooling) | [eBay](https://www.ebay.de/itm/306651580515)                                                                      |

## Hardware Specifications

### Per Node (Futro S740)

- **CPU**: Intel Celeron J4105 Quad-Core 1.5GHz
- **RAM**: 4GB (upgradeable to 16GB max)
- **Storage**: 32GB SSD (upgradeable)
- **Network**: Gigabit Ethernet
- **Cooling**: Passive (fanless)

## Cluster Architecture

Two different cluster configurations are possible with 4 nodes:

### Configuration 1: High Availability (HA) Setup

- **Control Plane Nodes**: 3x Futro S740
- **Worker Nodes**: 1x Futro S740 (expandable)

This configuration provides high availability for the Kubernetes control plane with three master nodes, ensuring cluster resilience in case of node failures. The control plane can tolerate the failure of one master node without service interruption.

### Configuration 2: Maximum Worker Capacity

- **Control Plane Nodes**: 1x Futro S740
- **Worker Nodes**: 3x Futro S740

This configuration maximizes the number of worker nodes available for running workloads. However, it provides no redundancy for the control plane - if the single master node fails, the cluster will be unavailable until it is restored.

### Configuration Decision

**For Homelab Setups: Recommended - Maximum Worker Capacity (1 Control Plane, 3 Workers)**

In typical homelab environments, there are already single points of failure higher up in the infrastructure stack (single router, single internet connection, single power supply, etc.). In these scenarios, the **Maximum Worker Capacity configuration (1 Control Plane, 3 Workers) is recommended** because:

- It provides more capacity for actual workloads (3 worker nodes vs. 1)
- The control plane redundancy doesn't add significant value when other infrastructure components are single points of failure
- Better resource utilization for running applications and services
- More practical for learning and experimentation

**Choose HA Setup (3 Control Plane, 1 Worker) if:**
- You have redundant infrastructure at higher levels (multiple internet connections, UPS systems, etc.)
- High availability and uptime are critical despite other single points of failure
- You prioritize control plane redundancy over worker capacity
- This is a production environment where control plane resilience is specifically required

## Rack Layout

The GeekPi 8HE Mini Rack is organized as follows (HE positions numbered from top to bottom):

| HE Position | Component      | HA Config (3 CP, 1 Worker)        | Max Worker Config (1 CP, 3 Workers) |
| ----------- | -------------- | ----------------------------------- | ----------------------------------- |
| HE 1        | Patch Panel    | Network patching and cable management | Network patching and cable management |
| HE 2        | Network Switch | 1 Gbit managed switch               | 1 Gbit managed switch               |
| HE 3        | Empty          | Reserved for future expansion       | Reserved for future expansion       |
| HE 4        | Empty          | Reserved for future expansion       | Reserved for future expansion       |
| HE 5        | Node 1         | Futro S740 - Control Plane Node     | Futro S740 - Control Plane Node     |
| HE 6        | Node 2         | Futro S740 - Control Plane Node     | Futro S740 - Worker Node            |
| HE 7        | Node 3         | Futro S740 - Control Plane Node     | Futro S740 - Worker Node            |
| HE 8        | Node 4         | Futro S740 - Worker Node            | Futro S740 - Worker Node            |

## Upgrade Recommendations

This cluster uses a lightweight software stack with **Kairos** (Alpine-based) and **k3s**, which makes 4GB RAM sufficient to start and run the cluster. However, consider the following upgrades for better performance and capacity:

1. **Storage Upgrade**: If no shared storage (NAS) is used, upgrade the SSD storage on each node to accommodate container images and persistent volumes.
2. **RAM Upgrade**: While 4GB is sufficient with the lightweight stack, upgrading to 8GB per node (minimum recommended) or 16GB per node (maximum capacity) will provide better performance and allow for more concurrent workloads.

### Upgrade Priority

- **Recommended**: Storage upgrade (32GB may be limiting for container images and logs)
- **Optional**: RAM upgrade (4GB is sufficient with Kairos/k3s, but more RAM improves performance and capacity)
