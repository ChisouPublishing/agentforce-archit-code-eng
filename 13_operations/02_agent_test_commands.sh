# Create a test in the org from the evaluation set (YAML); it is deployed as an AiEvaluationDefinition
sf agent test create --target-org <org> --api-name Return_Refund_Agent_Eval \
  --spec specs/Return_Refund_Agent-testSpec.yaml --test-runner testing-center

# For cases that do not check the subagent, remove the empty topic_sequence_match from the generated definition and redeploy
sf project deploy start --target-org <org> --metadata AiEvaluationDefinition:Return_Refund_Agent_Eval

# Run it and get the results as JSON
sf agent test run --target-org <org> --api-name Return_Refund_Agent_Eval \
  --wait 20 --result-format json --json > test-run.json

# The exit code is 0 even when tests fail. To use it as a quality gate, read the results and stop
python3 -c "import json,sys; r=json.load(open('test-run.json'))['result']; \
bad=[t['name'] for c in r['testCases'] for t in c['testResults'] if t['result']!='PASS']; \
print('failed:', bad); sys.exit(1 if bad else 0)"