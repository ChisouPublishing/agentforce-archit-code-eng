global with sharing class AFD_SubmitReturnRequestAction {

    @InvocableMethod(label='Submit Return Request'
        description='Processes a return the customer confirmed with the confirm button. Creates a refund request for $100 or less, or an approval request for larger amounts. Does nothing if not confirmed.')
    global static List<Result> submit(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        for (Request r : reqs) {
            Result res = new Result();
            res.submitted = false;
            AFD_ReturnConfirmation c = r == null ? null : r.confirmation;
            // (1) Do not run without human confirmation. Only the form checkbox counts as confirmation, not a "yes" in the conversation
            if (c == null || c.confirmed != true) {
                res.message = 'The return was not confirmed, so nothing was processed.';
                out.add(res); continue;
            }
            // (2) Stop if the amount shown on screen differs from the amount carried in the variable (prevents a mismatch between screen and processing)
            if (r.orderId == null || r.amount == null
                    || (c.refundAmount != null && c.refundAmount != r.amount)) {
                res.message = 'The confirmed details do not match the request, so a support agent will review it.';
                out.add(res); continue;
            }
            // (3) Delegate execution to the existing actions (they check the idempotency key and the amount limit)
            if (r.amount <= 100) {
                AFD_ExecuteRefundAction.Request x = new AFD_ExecuteRefundAction.Request();
                x.orderId = r.orderId; x.amount = r.amount;
                AFD_ExecuteRefundAction.Result y =
                    AFD_ExecuteRefundAction.run(new List<AFD_ExecuteRefundAction.Request>{ x })[0];
                res.submitted = y.succeeded == true;
                res.message = y.message;
                res.citations = citeRecord('REFUND:' + r.orderId, 'Refund request received ');
            } else {
                AFD_CreateApprovalRequestAction.Request x = new AFD_CreateApprovalRequestAction.Request();
                x.orderId = r.orderId; x.amount = r.amount;
                AFD_CreateApprovalRequestAction.Result y =
                    AFD_CreateApprovalRequestAction.create(new List<AFD_CreateApprovalRequestAction.Request>{ x })[0];
                res.submitted = y.created == true || String.isNotBlank(y.requestNumber);
                res.message = y.message;
                res.citations = citeRecord('APPROVAL:' + r.orderId, 'Approval request created ');
            }
            out.add(res);
        }
        return out;
    }

    // Return the refund record created by the request as the citation (source) of the response
    private static AiCopilot.GenAiCitationOutput citeRecord(String key, String labelPrefix) {
        List<Refund__c> recs = [SELECT Id, Name FROM Refund__c WHERE Idempotency_Key__c = :key WITH USER_MODE LIMIT 1];
        return recs.isEmpty() ? null : AFD_ReturnCitations.of(recs[0].Id, 'Refund__c', labelPrefix + recs[0].Name);
    }

    global class Request {
        @InvocableVariable(required=true label='Order Id'
            description='ID of the order confirmed in the quote. Passed from a conversation variable.') global Id orderId;
        @InvocableVariable(required=true label='Amount'
            description='Refund amount of the quote (USD). Passed from a conversation variable.') global Decimal amount;
        @InvocableVariable(required=true label='Confirmation'
            description='What the customer confirmed with the confirm button.') global AFD_ReturnConfirmation confirmation;
    }
    global class Result {
        @InvocableVariable(label='Submitted' description='Whether the request was accepted') global Boolean submitted;
        @InvocableVariable(label='Message' description='Text that can be shown to the customer as is') global String message;
        @InvocableVariable(label='Citations' description='Citation for the response (the refund request that was created)') global AiCopilot.GenAiCitationOutput citations;
    }
}
