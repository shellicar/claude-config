---
name: azure-devops-pipelines
description: Pipeline runs and configuration in Azure DevOps. Use when queuing/monitoring pipelines, configuring YAML triggers, checking build validation policies, or troubleshooting why pipelines didn't trigger.
---

# Azure DevOps Pipelines

Pipeline runs, configuration, triggers, and build validation policies.

## When Invoked

If the user invokes this skill, they likely want help with:
- **Running** pipelines (queuing, monitoring, checking status)
- **Configuring** pipelines (YAML triggers, path filters)
- **Maintaining** pipelines (build validation policies, consistency checks)
- **Troubleshooting** why pipelines didn't trigger or failed

Ask what they need help with if not clear from context.

## Pipeline Runs

```bash
# List recent pipeline runs - ALWAYS use --query-order QueueTimeDesc for fresh results
az pipelines runs list --project <Project> --query-order QueueTimeDesc --top 10 -o table

# List runs for specific pipeline
az pipelines runs list --project <Project> --pipeline-ids <PipelineId> --query-order QueueTimeDesc -o table

# Show specific run
az pipelines runs show --project <Project> --id <RunId> -o json

# Queue a pipeline run
az pipelines run --id <PipelineId> --branch <branch> --project <Project> --org https://dev.azure.com/<org>
```

**CRITICAL**: Always use `--query-order QueueTimeDesc` when listing pipeline runs. Without this flag, the API may return cached/stale results and miss recently queued or in-progress runs. This is especially important when checking if a pipeline was triggered or monitoring ongoing builds.

## Multi-Stage Pipelines

Multi-stage pipelines (e.g., with approval gates) show as "inProgress" until ALL stages complete, including those awaiting manual approval. There is no direct filter for "actively running" vs "awaiting approval" - you must check the individual run details.

## Pipeline Configuration

To find all pipelines and their YAML source files:

```bash
# List pipelines
az pipelines list --project <Project> --org https://dev.azure.com/<org> -o table

# Get YAML file for each pipeline (yamlFilename is nested, use grep)
az pipelines show --id <ID> --project <Project> --org https://dev.azure.com/<org> -o json | grep -o '"yamlFilename": "[^"]*"'
```

## Pipeline Triggers vs Build Validation Policies

Pipelines have two types of path-based triggers:

### 1. CI Triggers (in azure-pipelines.yml)

Trigger on merge to main:

```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - apps/api
    - packages/*
    exclude:
    - apps/api/azure-pipelines.yml
```

### 2. Build Validation Policies (branch policies)

Trigger on PR:

```bash
az repos policy list --project <Project> --org https://dev.azure.com/<org> -o json
```

Look for `type.displayName: "Build"` policies with `filenamePatterns`.

## Format Differences

- Pipeline triggers: `apps/api`, `packages/*` (no leading `/`)
- Build policies: `/apps/api/*`, `/packages/*` (with leading `/` and trailing `/*`)

These should be semantically equivalent but may drift.

## Investigating Trigger Issues

When investigating trigger issues:

1. Query pipelines and their YAML files
2. Extract trigger paths from YAML
3. Query build validation policies
4. Compare for consistency

## Pipeline Policy Sync Script

Use `~/.claude/skills/azure-devops-pipelines/scripts/pipeline-policy-sync.sh` to compare or sync YAML triggers with build validation policies:

```bash
# Compare YAML triggers with policy (show differences)
pipeline-policy-sync.sh --org <ORG> --project <PROJECT> \
  --yaml <path/to/azure-pipelines.yml> --pipeline-id <ID> --compare

# Sync policy to match YAML
pipeline-policy-sync.sh --org <ORG> --project <PROJECT> \
  --yaml <path/to/azure-pipelines.yml> --pipeline-id <ID> --sync
```

The script handles format conversion between YAML and policy patterns:
- YAML: `apps/api` → Policy: `/apps/api/*`
- YAML: `packages/*` → Policy: `/packages/*`
- YAML files: `apps/api/azure-pipelines.yml` → Policy: `/apps/api/azure-pipelines.yml` (no `/*`)

## Shared Templates

Changes to shared files (like `infrastructure/deploy/jobs/build.yml` or `templates/build/nodejs.yml`) may be used by multiple pipelines but only trigger pipelines that include those paths in their triggers.

This is important for:
- Understanding which pipelines will run when a file changes
- Ensuring changes to shared templates don't break pipelines that won't be triggered
- Deciding if path filters need to be updated

## Branch Policies

Query all branch policies:

```bash
az repos policy list --project <Project> --org https://dev.azure.com/<org> -o json
```

Common policy types:
- `Require a merge strategy` - squash only, etc.
- `Comment requirements` - all comments must be resolved
- `Minimum number of reviewers` - required approvals
- `Required reviewers` - specific people must approve
- `Build` - build validation policies with filename patterns
- `Work item linking` - require linked work items
