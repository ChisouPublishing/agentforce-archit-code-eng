public with sharing class CreateApprovalRequestAction {

    @InvocableMethod(label='Create Approval Request'
        description='Creates an approval request for a refund over the automatic processing limit and returns the request number. Does not execute the refund. Later calls for the same order return the existing request number.')
    public static List<Result> create(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        Set<Id> orderIds = new Set<Id>();
        Set<String> keys = new Set<String>();
        for (Request r : reqs) {
            if (r != null && r.orderId != null) {
                orderIds.add(r.orderId);
                keys.add(keyOf(r.orderId));
            }
        }
        Map<Id, Order> orders = new Map<Id, Order>([
            SELECT Id, TotalAmount FROM Order WHERE Id IN :orderIds WITH USER_MODE
        ]);
        Map<String, Refund__c> existing = new Map<String, Refund__c>();
        for (Refund__c rf : [SELECT Id, Name, Idempotency_Key__c FROM Refund__c
                             WHERE Idempotency_Key__c IN :keys WITH USER_MODE]) {
            existing.put(rf.Idempotency_Key__c, rf);
        }

        // Create all new requests in a single DML statement
        List<Refund__c> toInsert = new List<Refund__c>();
        Map<Integer, Refund__c> newByIndex = new Map<Integer, Refund__c>();
        for (Integer i = 0; i < reqs.size(); i++) {
            Request r = reqs[i];
            Result res = new Result();
            res.created = false;
            out.add(res);
            Order o = (r == null) ? null : orders.get(r.orderId);
            if (o == null) {
                res.message = 'We could not find the order. A support representative will review it.';
            } else if (existing.containsKey(keyOf(o.Id))) {
                res.requestNumber = existing.get(keyOf(o.Id)).Name;
                res.message = 'Your approval request has already been received.';
            } else if (r.amount == null || r.amount <= 0 || r.amount > o.TotalAmount) {
                res.message = 'We could not confirm the requested amount. A support representative will review it.';
            } else {
                Refund__c rec = new Refund__c(Order__c = o.Id, Amount__c = r.amount,
                    Status__c = 'PendingApproval', Idempotency_Key__c = keyOf(o.Id));
                toInsert.add(rec);
                newByIndex.put(i, rec);
                existing.put(keyOf(o.Id), rec);   // Also merges duplicates within the same call
            }
        }
        if (!toInsert.isEmpty()) {
            try {
                insert as user toInsert;
                Map<Id, String> names = new Map<Id, String>();
                for (Refund__c rf : [SELECT Id, Name FROM Refund__c WHERE Id IN :toInsert WITH USER_MODE]) {
                    names.put(rf.Id, rf.Name);
                }
                for (Integer i : newByIndex.keySet()) {
                    out[i].created = true;
                    out[i].requestNumber = names.get(newByIndex.get(i).Id);
                    out[i].message = 'Your approval request has been received. Approval takes 1 to 2 business days.';
                }
            } catch (Exception e) {
                for (Integer i : newByIndex.keySet()) {
                    out[i].message = 'Something went wrong while creating the request. I will connect you with a support representative.';
                }
                System.debug(LoggingLevel.ERROR, 'Approval request failed: ' + e.getTypeName());
            }
        }
        return out;
    }

    private static String keyOf(Id orderId) { return 'APPROVAL:' + orderId; }

    public class Request {
        @InvocableVariable(required=true label='Order Id'
            description='ID of the order identified during identity verification.') public Id orderId;
        @InvocableVariable(required=true label='Amount'
            description='Refund amount to request (USD). Pass the value returned by the eligibility action as is.') public Decimal amount;
    }
    public class Result {
        @InvocableVariable(label='Created'
            description='Whether this call created a new request') public Boolean created;
        @InvocableVariable(label='Request Number'
            description='Approval request number. Can be shared with the customer') public String requestNumber;
        @InvocableVariable(label='Message'
            description='Text that can be shown to the customer as is')     public String message;
    }
}