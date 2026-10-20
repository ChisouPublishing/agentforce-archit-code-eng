# Template versions (Chapter 5, section 04 "Check It in the UI: Create and Change a Version")

- `Summarize_Case_For_Handoff.genAiPromptTemplate-meta.xml`: retrieved with `sf project retrieve start -m GenAiPromptTemplate:Summarize_Case_For_Handoff` after version 2 (five blocks: role, context, task, constraints, output format) was created and activated in Prompt Builder (org `agentforce-dev`; retrieval pending for the English org — the file currently holds the localized text of the Japanese-edition retrieval)
- `retrieve-diff.txt`: diff against the state before retrieval (version 1 only). `templateVersions` becomes two entries, and `activeVersionIdentifier` changes from `_1` to `_2`
- Screenshots and recordings: `codes/agentforce-dev/validation/prompt-versions/` (created by the English-org run)
