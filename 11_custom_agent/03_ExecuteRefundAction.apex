public with sharing class ExecuteRefundAction {

    @InvocableMethod(label='Execute Refund'
        description='Accepts a refund request. Only one refund is accepted per order; later calls do not create a new refund and return the existing result.')
    public static List<Result> run(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        // This sample handles single refunds only. Bulk input from Flow is not processed; one result is returned per request.
        if (reqs.size() > 1) {
            for (Request ignored : reqs) {
                Result rejected = new Result();
                rejected.succeeded = false;
                rejected.message = 'Multiple refunds are reviewed by a support representative.';
                out.add(rejected);
            }
            return out;
        }

        for (Request r : reqs) {
            Result res = new Result();
            if (r == null || r.orderId == null) {
                res.succeeded = false;
                res.message = 'An order ID is required.';
                out.add(res);
                continue;
            }
            // Build the idempotency key from a business key, not the conversation ID.
            // If the key is the business rule itself ("one refund per order"),
            // restarting the conversation or coming from another channel cannot cause a double refund.
            String key = 'REFUND:' + r.orderId;
            Savepoint checkpoint = Database.setSavepoint();
            try {
                // (1) Look up an existing refund by idempotency key (guards against agent retries)
                List<Refund__c> existing = [
                    SELECT Id, Status__c, Amount__c FROM Refund__c
                    WHERE Idempotency_Key__c = :key WITH USER_MODE LIMIT 1
                ];
                if (!existing.isEmpty()) {
                    if (existing[0].Amount__c != r.amount) {
                        res.succeeded = false;
                        res.message = 'This order already has a refund request for a different amount. A support representative will review it.';
                    } else {
                        res.succeeded = existing[0].Status__c == 'Requested' || existing[0].Status__c == 'Submitted';
                        res.alreadyProcessed = true;
                        res.message = res.succeeded
                            ? 'This request has already been accepted. This does not mean the payment is complete.'
                            : 'The existing request needs review by a support representative.';
                    }
                    out.add(res);
                    continue;
                }

                // (2) Validate the amount limit in Apex as well.
                //    available when in Agent Script is the first line of defense, but this action
                //    can also be called from other paths such as Flow, so always validate here too.
                if (r.amount == null || r.amount <= 0 || r.amount > 100) {
                    res.succeeded = false;
                    res.message   = 'The amount is outside the range for automatic processing, so a support representative will review it.';
                    out.add(res);
                    continue;
                }
                List<Order> orders = [SELECT Id, TotalAmount FROM Order
                                      WHERE Id = :r.orderId WITH USER_MODE LIMIT 1];
                if (orders.isEmpty() || r.amount > orders[0].TotalAmount) {
                    res.succeeded = false;
                    res.message = 'We could not confirm the order or the amount. A support representative will review it.';
                    out.add(res);
                    continue;
                }

                Refund__c rec = new Refund__c(
                    Order__c           = r.orderId,
                    Amount__c          = r.amount,
                    Status__c          = 'Requested',
                    Idempotency_Key__c = key
                );
                // The field has a unique constraint, so even if sharing hides an existing refund,
                // a second INSERT fails with DUPLICATE_VALUE.
                insert as user rec;

                // Do not wait for the external payment synchronously. Waiting blocks the whole conversation,
                // and handling retries inside the conversation risks a double refund.
                System.enqueueJob(new RefundQueueable(rec.Id));

                res.succeeded = true;
                res.message   = 'Your refund request has been accepted. Payment completion will be confirmed separately.';
            } catch (Exception e) {
                Database.rollback(checkpoint);
                // Never throw exceptions to the agent, including insufficient access or unique constraint violations.
                // Return only text that is safe to show the user, and log the details.
                res.succeeded = false;
                res.message   = 'Something went wrong during processing. I will connect you with a support representative.';
                System.debug(LoggingLevel.ERROR, 'Refund request failed: ' + e.getTypeName());
            }
            out.add(res);
        }
        return out;
    }

    public class Request {
        @InvocableVariable(required=true label='Order Id'
            description='ID of the order identified during identity verification.') public Id orderId;
        @InvocableVariable(required=true label='Amount'
            description='Refund amount (USD). Pass the value returned by the eligibility action as is.') public Decimal amount;
    }
    public class Result {
        @InvocableVariable(label='Succeeded'
            description='Whether the request was accepted. Does not mean the payment is complete') public Boolean succeeded;
        @InvocableVariable(label='Already Processed'
            description='Whether an already accepted refund was returned')         public Boolean alreadyProcessed = false;
        @InvocableVariable(label='Retryable'
            description='Whether retrying with the same input is safe. Always false for this action; a support representative decides on retries') public Boolean retryable = false;
        @InvocableVariable(label='Message'
            description='Text that can be shown to the customer as is')  public String message;
    }
}