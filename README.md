# Azure Administration Scripts

A collection of standalone Bash scripts for Microsoft Azure administration,
resource inventory, security review, cost visibility, monitoring, and routine
infrastructure operations.

The repository currently contains 23 supported scripts. It is a script library
rather than a single application, so each script has its own purpose, parameters,
prerequisites, and required Azure permissions.

## Script categories

| Location | Scripts | What they cover |
| --- | ---: | --- |
| [`Account/`](Account/) | 1 | Active Azure identity, tenant, subscription, cloud, and default-location verification. |
| [`CostManagement/`](CostManagement/) | 2 | Daily and month-to-date Azure Cost Management reporting. |
| [`Functions/`](Functions/) | 3 | Function App inventory, function discovery, and live log streaming. |
| [`IdentitySecurity/`](IdentitySecurity/) | 2 | Entra application credential-expiration auditing and Owner role assignment reporting. |
| [`Monitoring/`](Monitoring/) | 3 | Activity Log review, Log Analytics workspace inventory, and metric alert discovery. |
| [`Networking/`](Networking/) | 3 | Virtual network, unattached public IP, and load balancer inventory. |
| [`SQLDatabases/`](SQLDatabases/) | 3 | Azure SQL logical server and database inventory, plus firewall-rule review. |
| [`Storage/`](Storage/) | 3 | Storage account inventory, public blob-access review, and directory synchronization. |
| [`VirtualMachines/`](VirtualMachines/) | 3 | VM inventory, unattached managed disk discovery, and tag-based VM operations. |

### Repository organization

Scripts are grouped by Azure service or administrative purpose. The repository root
is reserved for documentation and repository-wide configuration. Shared Bash helpers
are stored in [`Shared/`](Shared/), validation scripts are stored in
[`Tests/`](Tests/), and the original learning example is preserved in
[`Legacy/`](Legacy/).

## Requirements and compatibility

- Bash 3.2 or newer
- [Azure CLI 2.x](https://learn.microsoft.com/cli/azure/install-azure-cli)
- [`jq`](https://jqlang.org/download/)
- An authenticated Azure CLI session and the permissions required by the selected script
- Storage Blob Data Contributor or equivalent data-plane access for storage container
  audits and synchronization
- Microsoft Graph application read permissions for the Entra credential audit

Storage synchronization uses the preview `az storage blob sync` command and passes
its dry-run option through to AzCopy. Preview command behavior can change between
Azure CLI releases.

The scripts use the active Azure CLI cloud, tenant, and subscription. Set the target
subscription with `az account set --subscription NAME_OR_ID` before running them.
Review a script's `--help` output and source before using it, particularly in a
production subscription.

## Repository validation

Run the repository checks from its root:

```bash
make check
```

The validation checks Bash syntax, executable permissions, and every supported
script's help path. ShellCheck also runs when it is installed.

## Getting started

Clone the repository:

```bash
git clone https://github.com/ryroeu/Azure.git
cd azure
```

Sign in, select a subscription, and confirm the active Azure context:

```bash
az login
az account set --subscription my-sandbox-subscription
./Account/whoami.sh
```

Inspect a script's help before using it:

```bash
./VirtualMachines/inventory.sh --help
```

Run a read-only inventory script:

```bash
./VirtualMachines/inventory.sh
```

## Important safety notice

Some scripts can change cloud resources, stream operational data, synchronize or
delete blobs, or perform operations that incur charges. Before using a script in
production:

1. Read the complete script and verify its parameters and prerequisites.
2. Confirm the active cloud, tenant, and subscription.
3. Test it in a non-production environment.
4. Use an identity with only the permissions required for the task.
5. Review the preview before supplying `--execute`.
6. Add `--yes` only in reviewed automation where interactive confirmation is not
   possible.

Do not store client secrets, storage keys, SAS tokens, passwords, access tokens, or
other credentials in scripts or commit them to the repository.
