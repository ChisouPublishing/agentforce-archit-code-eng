String sessionId = null; // New conversation. To continue one, pass the ID you already have.
// Ask the agent from inside existing business logic
String agentApiName = 'Order_Support_Agent';
Invocable.Action action =
    Invocable.Action.createCustomAction('generateAiAgentResponse', agentApiName);
action.setInvocationParameter('userMessage', 'Summarize the status of order A-10023');
if (sessionId != null) {
    action.setInvocationParameter('sessionId', sessionId);   // To continue the conversation
}
List<Invocable.Action.Result> results = action.invoke();
String reply;
if (!results.isEmpty() && results[0].isSuccess()) {
    reply = (String) results[0].getOutputParameters().get('agentResponse');
} else {
    System.debug(LoggingLevel.WARN, 'The agent call failed.');
}