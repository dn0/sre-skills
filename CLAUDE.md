# SRE Skills for Claude

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

## Skill Structure

```
skills/<skill-name>/
├── SKILL.md              # Instructions with YAML frontmatter
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

## Design Principles

1. **Scripts for reliability** - Put API calls, auth, URL encoding in executable scripts
2. **Save before analyze** - Fetch data to temp files, then analyze (avoids re-fetching)
3. **Compact output** - Prefer CSV over JSON when schema is known (~14x smaller)
4. **Generate UI URLs** - Always provide URLs for humans to view in native UIs
5. **Use standard tools** - `awk`, `jq`, `gcloud` for analysis
