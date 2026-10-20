global with sharing class AFD_PrepareReturnQuoteAction {

    // Return reason code -> text shown to the customer. Only the values offered in the form are accepted
    @TestVisible
    private static final Map<String, String> REASONS = new Map<String, String>{
        'DEFECT' => 'Defective or damaged', 'WRONG_ITEM' => 'Received the wrong item',
        'SIZE' => 'Wrong size or specifications', 'CHANGED_MIND' => 'Changed my mind'
    };

    @InvocableMethod(label='Prepare Return Quote'
        description='Uses the return request form to run identity verification and the return eligibility check, and returns a quote that includes the expected refund amount. Does not process a refund.')
    global static List<Result> prepare(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        for (Request r : reqs) {
            out.add(prepareOne(r == null ? null : r.request));
        }
        return out;
    }

    private static Result prepareOne(AFD_ReturnRequestForm form) {
        Result res = new Result();
        AFD_ReturnQuote q = new AFD_ReturnQuote();
        q.verified = false; q.eligible = false; q.needsApproval = false; q.refundAmount = 0;
        res.quote = q;

        // (1) Validate the form values. Stop here instead of letting the LLM fill in missing values
        if (form == null || String.isBlank(form.orderNumber) || String.isBlank(form.emailTail4)
                || !REASONS.containsKey(form.reasonCode) || form.unopened == null) {
            return finish(res, 'Required fields in the form are missing.');
        }
        q.orderNumber = form.orderNumber.trim();
        q.reasonLabel = REASONS.get(form.reasonCode);

        // (2) Reuse the existing action for identity verification (keep the matching rules in one place)
        AFD_VerifyCustomerAction.Request vr = new AFD_VerifyCustomerAction.Request();
        vr.orderNumber = q.orderNumber;
        vr.emailTail4 = form.emailTail4.trim();
        AFD_VerifyCustomerAction.Result v =
            AFD_VerifyCustomerAction.verify(new List<AFD_VerifyCustomerAction.Request>{ vr })[0];
        if (v.verified != true) { return finish(res, v.message); }
        q.verified = true;
        res.orderId = v.orderId;
        List<Order> o = [SELECT EffectiveDate FROM Order WHERE Id = :v.orderId WITH USER_MODE LIMIT 1];
        q.orderDate = o.isEmpty() ? null : o[0].EffectiveDate;
        // Return the order record used for the decision as the citation (source) of the response
        res.citations = AFD_ReturnCitations.of(v.orderId, 'Order', 'Order used for the decision ' + q.orderNumber);

        // (3) Check the customer's declaration (opened) first. If either the declaration or the record says opened, reject
        if (form.unopened != true) {
            return finish(res, 'Opened items cannot be returned.');
        }

        // (4) Reuse the existing action for return eligibility too. The amount is decided here and carried in variables afterward
        AFD_CheckReturnEligibilityAction.Request er = new AFD_CheckReturnEligibilityAction.Request();
        er.orderId = v.orderId;
        AFD_CheckReturnEligibilityAction.Result e =
            AFD_CheckReturnEligibilityAction.check(new List<AFD_CheckReturnEligibilityAction.Request>{ er })[0];
        q.eligible = e.eligible == true;
        q.refundAmount = q.eligible ? e.refundAmount : 0;
        q.needsApproval = q.eligible && q.refundAmount > 100;
        String msg = e.reason;
        if (q.eligible) {
            msg += q.needsApproval
                ? ' The refund amount is over $100, so confirming will create an approval request.'
                : ' Review the details and confirm.';
        }
        return finish(res, msg);
    }

    private static Result finish(Result res, String message) {
        res.quote.message = message;
        res.verified = res.quote.verified;
        res.eligible = res.quote.eligible;
        res.refundAmount = res.quote.refundAmount;
        res.needsApproval = res.quote.needsApproval;
        res.orderNumber = res.quote.orderNumber;
        res.message = message;
        return res;
    }

    global class Request {
        @InvocableVariable(required=true label='Return Request'
            description='Contents of the return request form (order number, last 4 characters of the email, return reason, unopened declaration).')
        global AFD_ReturnRequestForm request;
    }
    global class Result {
        @InvocableVariable(label='Quote' description='Quote shown on the screen card')
        global AFD_ReturnQuote quote;
        @InvocableVariable(label='Verified' description='Whether identity verification succeeded') global Boolean verified;
        @InvocableVariable(label='Eligible' description='Whether the return can be accepted') global Boolean eligible;
        @InvocableVariable(label='Order Id' description='ID of the verified order') global Id orderId;
        @InvocableVariable(label='Order Number' description='Order number of the quote') global String orderNumber;
        @InvocableVariable(label='Refund Amount' description='Expected refund amount (USD)') global Decimal refundAmount;
        @InvocableVariable(label='Needs Approval' description='Whether confirming creates an approval request') global Boolean needsApproval;
        @InvocableVariable(label='Message' description='Text that can be shown to the customer as is') global String message;
        @InvocableVariable(label='Citations' description='Citation for the response (the order record used for the decision)') global AiCopilot.GenAiCitationOutput citations;
    }
}
