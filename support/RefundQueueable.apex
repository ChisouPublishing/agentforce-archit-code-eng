public with sharing class RefundQueueable implements Queueable, Database.AllowsCallouts {
    private Id refundId;
    public RefundQueueable(Id refundId) { this.refundId = refundId; }
    public void execute(QueueableContext context) {
        Refund__c refund = [SELECT Id, Order__c, Amount__c, Status__c, Idempotency_Key__c
                           FROM Refund__c WHERE Id = :refundId WITH USER_MODE];
        if (refund.Status__c != 'Requested') { return; }
        HttpRequest request = new HttpRequest();
        request.setEndpoint('callout:AgentforceRefundGateway/refunds');
        request.setMethod('POST');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Idempotency-Key', refund.Idempotency_Key__c);
        request.setBody(JSON.serialize(new Map<String, Object>{
            'orderId' => refund.Order__c, 'amount' => refund.Amount__c,
            'requestId' => refund.Idempotency_Key__c }));
        try {
            HttpResponse response = new Http().send(request);
            refund.Status__c = response.getStatusCode() >= 200 && response.getStatusCode() < 300
                ? 'Submitted' : 'NeedsReview';
        } catch (CalloutException e) {
            refund.Status__c = 'NeedsReview';
        }
        update as user refund;
    }
}
