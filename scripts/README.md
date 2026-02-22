# Oboon Scripts

Utility scripts for managing Oboon infrastructure.

## Scripts

### create-resources.sh

Creates Hetzner VM and Modal GPU resources for load testing.

```bash
# Create resources for 100 concurrent calls
./scripts/create-resources.sh --calls 100

# Create resources for 1000 concurrent calls
./scripts/create-resources.sh --calls 1000

# Create only Hetzner VM
./scripts/create-resources.sh --calls 100 --vm-only

# Custom VM name
./scripts/create-resources.sh --calls 100 --name my-livekit
```

**Workload Tiers:**
| Calls | VM Type | Specs |
|-------|---------|-------|
| 10-50 | CPX21 | 3 vCPU, 4GB RAM |
| 100-300 | CPX22 | 3 vCPU, 8GB RAM |
| 500-1000 | CPX32 | 4 vCPU, 8GB RAM |
| 1000+ | CPX42 | 8 vCPU, 16GB RAM |

**What it does:**
1. Creates Hetzner VM with appropriate specs
2. Installs LiveKit server + CLI
3. Configures systemd service
4. Generates API credentials
5. Saves state to `.vm-state.json`

### remove-resources.sh

Removes all resources created by `create-resources.sh`.

```bash
# Remove everything
./scripts/remove-resources.sh --all

# Remove only Hetzner VM
./scripts/remove-resources.sh --vm

# Remove only Modal resources
./scripts/remove-resources.sh --modal
```

**What it does:**
1. Deletes Hetzner VMs with `oboon-` prefix
2. Stops Modal apps
3. Cleans up local state files

## Prerequisites

- **hcloud** (Hetzner CLI): `brew install hcloud`
- **modal** (Modal CLI): `pip install modal`
- **jq**: `brew install jq`
- **HCLOUD_TOKEN**: Set in environment

## State Files

- `.vm-state.json` - VM details and credentials
- `.modal-state.json` - Modal app state

## Example Workflow

```bash
# 1. Create resources for load testing
./scripts/create-resources.sh --calls 100

# 2. Run load test
export LIVEKIT_URL="ws://<VM_IP>:7880"
export LIVEKIT_API_KEY="<from .vm-state.json>"
export LIVEKIT_API_SECRET="<from .vm-state.json>"
lk perf load-test --room test-100 --publishers 50 --subscribers 50 --duration 60s

# 3. Clean up when done
./scripts/remove-resources.sh --all
```
