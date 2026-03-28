# SRE Skills for Claude and other LLM Agents

Claude Skills for Site Reliability Engineers, DevOps, and Cloud engineers focused on monitoring and observability.

## Documentation

- [Skills Overview](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview)
- [Skills Best Practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices)

## Skills

Skills are in `skills/` (symlinked to `.claude/skills/`).

### Logs
- `gcp-logs`
- `grafana-loki`

### Metrics
- `gcp-metrics`
- `grafana-mimir`

### Traces
- `gcp-traces`
- `grafana-tempo`

### Alerts
- `gcp-alerts`
- `grafana-alerts`

## Skill Structure

```
skills/<skill-name>/
├── SKILL.md              # Instructions with YAML frontmatter (for Claude Code / human use)
├── tool.yaml             # Machine-readable tool definitions (for sre-bot / programmatic use)
└── scripts/
    ├── query.sh          # Data fetching
    └── url.sh            # UI URL generation
```

### SKILL.md Format

```yaml
---
name: skill-name
description: What it does. When to use it.
---

# Skill Name

[Concise instructions, under 500 lines]
```

### tool.yaml Format

`tool.yaml` is the machine-readable counterpart to `SKILL.md`. While `SKILL.md` teaches an interactive LLM (like Claude Code) how to use the scripts via natural language, `tool.yaml` declares the same information as structured data so that automated systems can load and call the scripts without free-form interpretation.

Each `tool.yaml` defines one or more tools. A tool maps to a single script and declares its name, description, and typed parameters. The parameter order in `tool.yaml` matches the positional argument order of the underlying script.

```yaml
tools:
  - name: gcp_logs_query                    # Unique tool name (snake_case)
    description: "Query GCP Cloud Logging"  # When and why to use this tool
    script: scripts/query.sh                # Relative path to the script
    parameters:
      - name: project                       # Maps to $1
        type: string
        required: true
        description: "GCP project ID"
      - name: filter                        # Maps to $2
        type: string
        required: true
        description: "Cloud Logging filter expression"
      - name: limit                         # Maps to $3 (optional, has default)
        type: integer
        default: 1000
        description: "Max entries to return"
```

**Parameter fields:**
- `name` — Argument name (used by the caller, mapped to positional arg by order)
- `type` — `string`, `integer`, `number`, or `boolean`
- `required` — If true, the caller must provide this argument
- `default` — Value used when the caller omits the argument
- `description` — What this argument does
- `enum` — Optional list of allowed values

**Conventions:**
- Tool names are prefixed with the skill name in snake_case (e.g., `gcp_logs_query`, `grafana_loki_url`)
- Parameter order must match the script's positional arguments (`$1`, `$2`, ...)
- Optional parameters with defaults should come after required parameters
- Descriptions should be specific enough for an LLM to choose the right tool and pass correct arguments

## Design Principles

1. **Scripts for reliability** – Put API calls, auth, URL encoding in executable scripts
2. **Save before analyze** – Fetch data to temp files, then analyze (avoids re-fetching)
3. **Compact output** – Prefer CSV over JSON when schema is known or when working with many logs (~15x smaller)
4. **Generate UI URLs** – Always provide URLs for humans to view in native UIs
5. **Use standard tools** – `grep`, `awk`, `jq`, `sed`, `python` for analysis
