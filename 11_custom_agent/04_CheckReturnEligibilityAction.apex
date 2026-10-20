public with sharing class CheckReturnEligibilityAction {

    // Return window (days from the purchase date)
    private static final Integer RETURN_WINDOW_DAYS = 30;

    @InvocableMethod(label='Check Return Eligibility'
        description='Decides whether the order can be returned from the purchase date and opened status, and returns the expected refund amount. The reason goes in reason. Does not start a refund.')
    public static List<Result> check(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        Set<Id> orderIds = new Set<Id>();
        for (Request r : reqs) {
            if (r != null && r.orderId != null) { orderIds.add(r.orderId); }
        }
        // Only 2 SOQL queries even for bulk calls (200 records from Flow stay within limits)
        Map<Id, Order> orders = new Map<Id, Order>([
            SELECT Id, EffectiveDate, TotalAmount, Is_Opened__c FROM Order
            WHERE Id IN :orderIds WITH USER_MODE
        ]);
        Set<Id> alreadyRequested = new Set<Id>();
        for (Refund__c rf : [SELECT Order__c FROM Refund__c
                             WHERE Order__c IN :orderIds WITH USER_MODE]) {
            alreadyRequested.add(rf.Order__c);
        }

        Date earliest = Date.today().addDays(-RETURN_WINDOW_DAYS);
        for (Request r : reqs) {
            Result res = new Result();
            res.eligible = false;
            res.refundAmount = 0;
            Order o = (r == null) ? null : orders.get(r.orderId);
            if (o == null) {
                res.reason = 'We could not find the order.';
            } else if (alreadyRequested.contains(o.Id)) {
                res.reason = 'This order already has an accepted refund or an approval request. A support representative will check its status.';
            } else if (o.Is_Opened__c) {
                res.reason = 'Opened items cannot be returned.';
            } else if (o.EffectiveDate == null || o.EffectiveDate < earliest) {
                res.reason = 'The item cannot be returned because more than ' + RETURN_WINDOW_DAYS + ' days have passed since purchase.';
            } else if (o.TotalAmount == null || o.TotalAmount <= 0) {
                res.reason = 'We could not determine the refund amount.';
            } else {
                res.eligible = true;
                res.refundAmount = o.TotalAmount;
                res.reason = 'The item meets the return conditions (within ' + RETURN_WINDOW_DAYS + ' days of purchase and unopened).';
            }
            out.add(res);
        }
        return out;
    }

    public class Request {
        @InvocableVariable(required=true label='Order Id'
            description='ID of the order identified during identity verification.') public Id orderId;
    }
    public class Result {
        @InvocableVariable(label='Eligible'
            description='Whether the return can be accepted')        public Boolean eligible;
        @InvocableVariable(label='Refund Amount'
            description='Expected refund amount (USD). 0 if the return cannot be accepted') public Decimal refundAmount;
        @InvocableVariable(label='Reason'
            description='Reason for the decision. Text that can be shown to the customer as is') public String reason;
    }
}