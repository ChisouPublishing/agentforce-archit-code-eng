# 1) Create an External Client App and grant the OAuth scopes
#    api / refresh_token,offline_access / chatbot_api / sfap_api
#    Enable the Client Credentials Flow and set Run As to an API-only user

# 2) Get an access token
curl https://{MY_DOMAIN}/services/oauth2/token \
  --header 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=client_credentials' \
  --data-urlencode 'client_id={CONSUMER_KEY}' \
  --data-urlencode 'client_secret={CONSUMER_SECRET}'

# 3) Start a session
curl -X POST https://api.salesforce.com/einstein/ai-agent/v1/agents/{AGENT_ID}/sessions \
  -H 'Authorization: Bearer {ACCESS_TOKEN}' \
  -H 'Content-Type: application/json' \
  -d '{
        "externalSessionKey": "{UUID}",
        "instanceConfig": { "endpoint": "https://{MY_DOMAIN}" },
        "streamingCapabilities": { "chunkTypes": ["Text"] },
        "bypassUser": true
      }'
# -> Returns the sessionId and the links for sending messages and ending the session

# 4) Send a message (SSE streaming)
curl -X POST https://api.salesforce.com/einstein/ai-agent/v1/sessions/{SESSION_ID}/messages/stream \
  -H 'Authorization: Bearer {ACCESS_TOKEN}' \
  -H 'Content-Type: application/json' \
  -d '{"message": {"sequenceId": 1, "type": "Text", "text": "What is the shipping status of order A-10023?"}}'

# 5) End the session
curl -X DELETE https://api.salesforce.com/einstein/ai-agent/v1/sessions/{SESSION_ID} \
  -H 'Authorization: Bearer {ACCESS_TOKEN}'