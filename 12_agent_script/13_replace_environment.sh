# Put the following placeholder in the template's access block
#   access:
#       default_agent_user: "${AGENT_USER_EMAIL}"
# Set AGENT_USER_EMAIL to a Salesforce username in email format
# Replace MyAgent with the name of the bundle to migrate
set -eu
: "${AGENT_USER_EMAIL:?Set the agent user name}"
: "${TARGET_ORG:?Set the target org}"

# This example is for CI/CD. It requires envsubst and a .agent.tpl file
# Replace only the listed variable
envsubst '${AGENT_USER_EMAIL}' \
  < force-app/main/default/aiAuthoringBundles/MyAgent/MyAgent.agent.tpl \
  > force-app/main/default/aiAuthoringBundles/MyAgent/MyAgent.agent

# Prepare the user, permissions, and action implementations, then validate and publish
sf agent validate authoring-bundle \
  --api-name MyAgent --target-org "$TARGET_ORG"
sf agent publish authoring-bundle \
  --api-name MyAgent --target-org "$TARGET_ORG"
# Check the publish result and activate the target version with sf agent activate