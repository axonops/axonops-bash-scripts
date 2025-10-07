# AxonOps Agent Setup Script

Automated installation and configuration script for the AxonOps monitoring agent on Apache Cassandra clusters.

For detailed documentation, visit [https://axonops.com/docs](https://axonops.com/docs)

## Overview

This script streamlines the deployment of AxonOps agents across Cassandra nodes by:
- Installing the appropriate AxonOps agent package for your Cassandra version
- Configuring the agent with your organization credentials
- Updating Cassandra JVM settings to load the agent
- Managing user permissions and service restarts

## Prerequisites

- Root or sudo access on the target Cassandra node
- Active internet connection to reach `agents.axonops.cloud`
- AxonOps organization credentials (agent key and organization name)
- APT, YUM, or DNF package manager
- Cassandra 3.x, 4.x, or 5.x installed and configured

## Quick Start

```bash
./axon-agent-setup.sh \
  -v 3.12 \
  -c /etc/cassandra \
  -b /usr/bin \
  -u cassandra \
  -g cassandra \
  -r true \
  -a localhost \
  -p 9042 \
  -k YOUR_AGENT_KEY \
  -o YOUR_ORGANIZATION \
  -j 8
```

## Parameters

### Required Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| `-v` | Cassandra version (Major.Minor format) | `3.12`, `4.1`, `5.0` |
| `-c` | Path to Cassandra configuration directory | `/etc/cassandra` |
| `-b` | Path to Cassandra bin directory (containing nodetool) | `/usr/bin` |
| `-u` | Cassandra Linux user | `cassandra` |
| `-g` | Cassandra Linux group | `cassandra` |
| `-a` | Cassandra native transport address | `localhost`, `0.0.0.0` |
| `-p` | Cassandra native transport port | `9042` |
| `-k` | AxonOps agent key (from AxonOps console) | `test_key` |
| `-o` | AxonOps organization name | `axondocs` |
| `-j` | Java version used by Cassandra | `8`, `11`, `17` |

### Optional Parameters

| Parameter | Description | Default | Example |
|-----------|-------------|---------|---------|
| `-r` | Restart Cassandra after configuration | `false` | `true` |
| `-h` | Display help message | - | - |

## Usage Examples

### Cassandra 4.0 with Java 11 (with restart)
```bash
./axon-agent-setup.sh \
  -v 4.0 \
  -c /etc/cassandra \
  -b /usr/bin \
  -u cassandra \
  -g cassandra \
  -r true \
  -a 127.0.0.1 \
  -p 9042 \
  -k abc123xyz \
  -o mycompany \
  -j 11
```

### Cassandra 3.11 with Java 8 (without restart)
```bash
./axon-agent-setup.sh \
  -v 3.11 \
  -c /opt/cassandra/conf \
  -b /opt/cassandra/bin \
  -u cassandra_user \
  -g cassandra_group \
  -r false \
  -a 0.0.0.0 \
  -p 9042 \
  -k def456uvw \
  -o production \
  -j 8
```

### Cassandra 5.0 with Java 11 (with restart)
```bash
./axon-agent-setup.sh \
  -v 5.0 \
  -c /etc/cassandra \
  -b /usr/bin \
  -u cassandra \
  -g cassandra \
  -r true \
  -a localhost \
  -p 9042 \
  -k ghi789rst \
  -o staging \
  -j 11
```

### Cassandra 5.0 with Java 17 (with restart)
```bash
./axon-agent-setup.sh \
  -v 5.0 \
  -c /etc/cassandra \
  -b /usr/bin \
  -u cassandra \
  -g cassandra \
  -r true \
  -a localhost \
  -p 9042 \
  -k jkl012mno \
  -o production \
  -j 17
```

## What the Script Does

1. **Validates inputs** - Checks all required parameters and verifies paths exist
2. **Tests connectivity** - Ensures `agents.axonops.cloud` is reachable
3. **Configures package repository** - Sets up APT/YUM/DNF repository for AxonOps packages
4. **Installs agent** - Downloads and installs the correct agent version for your Cassandra/Java combination
5. **Configures agent** - Creates `/etc/axonops/axon-agent.yml` with your credentials
6. **Updates Cassandra JVM** - Adds agent configuration to `cassandra-env.sh`
7. **Sets permissions** - Adds agent user to Cassandra group and vice versa
8. **Restarts services** - Optionally restarts Cassandra and starts the AxonOps agent

## Important Notes

### Cassandra Restart Behavior

- If `-r true` is specified:
  - Cassandra will be gracefully stopped (waits up to 120 seconds)
  - After stopping, Cassandra will be restarted
  - Script waits up to 300 seconds for Cassandra to become available
  - AxonOps agent starts after Cassandra is confirmed running

- If `-r false` is specified (or omitted):
  - Cassandra configuration is updated but **not restarted**
  - You must manually restart Cassandra for changes to take effect
  - AxonOps agent will start but won't report metrics until Cassandra restarts

### Package Selection Logic

The script automatically selects the correct agent package based on your Cassandra and Java versions:

- **Cassandra 4.x + Java 8**: `axon-cassandra4.x-agent-jdk8`
- **Cassandra 5.x + Java 11**: `axon-cassandra5.x-agent-jdk11`
- **Cassandra 5.x + Java 17**: `axon-cassandra5.x-agent-jdk17`
- **All other combinations**: `axon-cassandra{version}-agent`

### Supported Operating Systems

- **Debian/Ubuntu** (APT)
- **RHEL/CentOS** (YUM)
- **Fedora/RHEL 8+** (DNF)

## Getting Your AxonOps Credentials

1. Sign up or log in at [console.axonops.cloud](https://console.axonops.cloud)
2. Navigate to your organization settings
3. Generate or copy your **Agent Key** and **Organization** name
4. Use these values for the `-k` and `-o` parameters

## Troubleshooting

For comprehensive troubleshooting guides, see [https://axonops.com/docs/troubleshooting/](https://axonops.com/docs/troubleshooting/)

### "agents.axonops.cloud is unreachable"
- Check firewall rules allow HTTPS (443) to `agents.axonops.cloud`
- Verify internet connectivity: `curl https://agents.axonops.cloud/test.html`
- See [Network Requirements](https://axonops.com/docs/installation/) for details

### "Cassandra nodetool at location ... is not accessible"
- Ensure nodetool exists at the specified path
- Check file permissions allow execution

### "Cassandra Process did not start after 300 seconds"
- Check Cassandra logs: `journalctl -u cassandra -n 100`
- Verify Java agent path is correct in `cassandra-env.sh`
- Ensure sufficient system resources (memory, disk space)

### Agent not reporting metrics
- Verify Cassandra was restarted after agent installation
- Check agent logs: `journalctl -u axon-agent -n 100`
- Confirm agent key and organization are correct in `/etc/axonops/axon-agent.yml`

## Configuration Files

### Generated Files
- `/etc/axonops/axon-agent.yml` - Agent configuration
- `/etc/apt/sources.list.d/axonops-apt.list` or `/etc/yum.repos.d/axonops-yum.repo` - Package repository

### Modified Files
- `{cassandra_config_path}/cassandra-env.sh` - Updated with JVM agent configuration

## Post-Installation

After successful installation:

1. Visit [console.axonops.cloud](https://console.axonops.cloud)
2. Navigate to your cluster view
3. Verify the node appears in the dashboard
4. Metrics should begin appearing within 1-2 minutes

## Support

- **Documentation**: [https://axonops.com/docs](https://axonops.com/docs)
- **Agent Setup Guide**: [https://axonops.com/docs/installation/](https://axonops.com/docs/installation/)

## License

This script is provided as part of AxonOps tooling. Refer to your AxonOps license agreement.
