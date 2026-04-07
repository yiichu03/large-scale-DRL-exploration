# Agent Notes

## Temporary Files

- Do not place temporary clones, scratch outputs, or investigation artifacts in the system `/tmp` unless there is a hard technical requirement.
- Prefer repository-local temporary paths under `tmp/`.
- If the work should live outside the repository tree, prefer a visible user path under `/home/liuyi/` such as `~/tmp/`.
- For temporary comparison clones created by an agent in this repository, default to `tmp/agent_tmp/`.
- Clean up temporary artifacts when they are no longer needed, or document them explicitly if they are intentionally kept for follow-up work.
