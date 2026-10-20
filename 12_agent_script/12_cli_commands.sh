# From the repository root, move to the DX project used for verification
cd codes/agentforce-dev

# --- Compile-check an existing Agent Script (requires an org connection) ---
sf agent validate authoring-bundle \
  --api-name Order_Support_Agent --target-org agentforce-dev \
  --api-version 68.0 --json

# --- Publish after changing the Agent Script (each run adds a new version) ---
# Deploy the referenced Apex, fields, permissions, and so on beforehand
sf agent publish authoring-bundle \
  --api-name Order_Support_Agent --target-org agentforce-dev \
  --api-version 68.0 --json
# By default, the generated agent metadata is also retrieved
# (API 68.0: aiAgents/ and aiAgentDefinitionVersions/; up to 67.0: bots/ and genAiPlannerBundles/)
# Add --skip-retrieve to skip the retrieval

# --- Activate after publishing ---
# 1 is the version used during verification. After republishing, change it to the new number
sf agent activate --api-name Order_Support_Agent --version 1 \
  --target-org agentforce-dev --json

# --- Look up the verification order through the agent and assert the order number ---
sf apex run --file apex/live-agent-order.apex \
  --target-org agentforce-dev --json

# --- Retrieve existing metadata (separate from publishing and activation) ---
# The version name is <agent API name>#<version number>
sf project retrieve start --metadata AiAgentDefinition:Order_Support_Agent \
  --metadata 'AiAgentDefinitionVersion:Order_Support_Agent#1' \
  --target-org agentforce-dev --api-version 68.0