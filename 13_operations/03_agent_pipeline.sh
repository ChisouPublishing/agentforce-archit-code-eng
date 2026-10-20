#!/usr/bin/env bash
# Agent deployment pipeline (for a staging org). Run from the root of the DX project
#   ORG=<org> AGENT=<agent API name> METADATA="<type:name> ..." TESTS="<Apex test class> ..." EVAL=<evaluation API name> ./03_agent_pipeline.sh
# Limit METADATA to this agent's components. With RunSpecifiedTests, every Apex class you send
# needs 75% or more coverage from the specified tests, so sending unrelated classes makes validation fail
# Stops at the first failure (set -e). Send only versions that passed here to production, using the same steps
set -euo pipefail
: "${ORG:?}" "${AGENT:?}" "${METADATA:?}" "${TESTS:?}" "${EVAL:?}"
SRC=(); for m in $METADATA; do SRC+=(--metadata "$m"); done
json() { python3 -c "import json,sys; d=json.load(sys.stdin); print($1)"; }

echo '== 1. Check Agent Script syntax and references'
sf agent validate authoring-bundle --api-name "$AGENT" --target-org "$ORG"

echo '== 2. Run a validation-only deployment with Apex tests (the org does not change)'
tests=(); for t in $TESTS; do tests+=(--tests "$t"); done
out=$(sf project deploy validate --target-org "$ORG" "${SRC[@]}" \
        --test-level RunSpecifiedTests "${tests[@]}" --wait 30 --json) || { echo "$out" | json "d.get('message')"; exit 1; }
job=$(echo "$out" | json "d['result']['id']")

echo "== 3. Quick-deploy the validated deployment (${job}) without rerunning tests"
sf project deploy quick --job-id "$job" --target-org "$ORG" --wait 30

echo '== 4. Publish the agent and activate the latest version'
sf agent publish authoring-bundle --api-name "$AGENT" --target-org "$ORG"
version=$(sf data query --target-org "$ORG" --json --query \
  "SELECT VersionNumber FROM BotVersion WHERE BotDefinition.DeveloperName = '$AGENT' ORDER BY VersionNumber DESC LIMIT 1" \
  | json "d['result']['records'][0]['VersionNumber']")
sf agent activate --api-name "$AGENT" --version "$version" --target-org "$ORG"

echo "== 5. Run the evaluation set (${EVAL}) and stop on any failure"
sf agent test run --target-org "$ORG" --api-name "$EVAL" --wait 20 --result-format json --json > test-run.json
python3 - <<'PY'
import json, sys
r = json.load(open('test-run.json'))['result']
bad = [(c['testNumber'], t['name']) for c in r['testCases'] for t in c['testResults'] if t['result'] != 'PASS']
print('Evaluation run ID:', r.get('runId'), '/ failed:', bad or 'none')
sys.exit(1 if bad or r.get('status') != 'COMPLETED' else 0)
PY
echo "== Done: activated ${AGENT} version ${version}, and it passed the evaluation"