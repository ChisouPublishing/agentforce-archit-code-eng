// This example is verified with HttpCalloutMock. A real connection requires a named credential.
String requestKey = 'replace-with-persisted-refund-request-key';
Map<String, Object> result = new Map<String, Object>{ 'succeeded' => false, 'retryable' => false };
HttpRequest request = new HttpRequest();
request.setEndpoint('callout:AgentforceRefundGateway/refunds');
request.setMethod('POST');
request.setHeader('Content-Type', 'application/json');
request.setHeader('Idempotency-Key', requestKey);
request.setBody(JSON.serialize(new Map<String, Object>{ 'requestId' => requestKey }));
try {
    HttpResponse response = new Http().send(request);
    result.put('succeeded', response.getStatusCode() >= 200 && response.getStatusCode() < 300);
    result.put('userSafeMessage', (Boolean) result.get('succeeded')
        ? 'Your refund request has been sent. We will check the result.'
        : 'We could not confirm whether the request was received. A support representative will check.');
} catch (CalloutException e) {
    // Even after a timeout, the other side may have accepted the request. Do not resend automatically.
    result.put('userSafeMessage', 'We could not confirm whether the request was received. A support representative will check.');
    System.debug(LoggingLevel.WARN, 'Refund request requires reconciliation.');
}