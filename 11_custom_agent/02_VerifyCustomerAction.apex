public with sharing class VerifyCustomerAction {

    @InvocableMethod(
        label='Verify Customer'
        description='Checks the order number and the last 4 characters of the registered email address. Returns verified=true and the membership tier only on a match. On a mismatch, returns the failure count incremented by one.'
        category='Identity')
    public static List<Result> verify(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        Set<String> numbers = new Set<String>();
        for (Request req : reqs) {
            if (req != null && String.isNotBlank(req.orderNumber)) { numbers.add(req.orderNumber); }
        }
        Map<String, Order> byNumber = new Map<String, Order>();
        for (Order row : [SELECT Id, OrderNumber, AccountId, BillToContact.Email,
                                Account.Membership_Tier__c FROM Order
                          WHERE OrderNumber IN :numbers WITH USER_MODE]) {
            byNumber.put(row.OrderNumber, row);
        }

        for (Request r : reqs) {
            Result res = new Result();

            if (r == null) { r = new Request(); }
            Integer attempts = r.previousAttempts == null ? 0 : Math.max(0, r.previousAttempts);
            if (attempts >= 3) {
                res.verified = false;
                res.attemptsUsed = attempts;
                res.message = 'You have reached the maximum number of attempts. I will connect you with a support representative.';
                out.add(res);
                continue;
            }
            List<Order> orders = new List<Order>();
            if (byNumber.containsKey(r.orderNumber)) { orders.add(byNumber.get(r.orderNumber)); }

            if (orders.isEmpty()) {
                // Do not distinguish "order does not exist" from "email does not match".
                // Otherwise, brute-forcing order numbers would reveal which orders exist.
                res.verified     = false;
                res.attemptsUsed = attempts + 1;
                res.message      = 'The order number or email address did not match.';
                out.add(res);
                continue;
            }

            Order o = orders[0];
            String localPart = (o.BillToContact == null || o.BillToContact.Email == null)
                             ? '' : o.BillToContact.Email.split('@')[0];
            String tail4 = localPart.length() >= 4 ? localPart.right(4) : localPart;

            if (!String.isBlank(r.emailTail4) && tail4.equalsIgnoreCase(r.emailTail4)) {
                res.verified     = true;
                res.orderId      = o.Id;
                res.customerTier = (o.Account.Membership_Tier__c == 'Premium')
                                 ? 'premium' : 'standard';
                res.attemptsUsed = attempts;      // Not incremented on success
                res.message      = 'Identity verification is complete.';
            } else {
                res.verified     = false;
                res.attemptsUsed = attempts + 1;
                res.message      = 'The order number or email address did not match.';
            }
            out.add(res);
        }
        return out;
    }

    public class Request {
        @InvocableVariable(required=true label='Order Number'
            description='The order number the customer provided. Example: A-10023')
        public String orderNumber;
        @InvocableVariable(required=true label='Email Tail 4'
            description='The last 4 characters before the @ of the registered email address.')
        public String emailTail4;
        @InvocableVariable(label='Previous Attempts'
            description='Number of failed attempts so far. Passed from the conversation variable.')
        public Integer previousAttempts = 0;
    }

    public class Result {
        @InvocableVariable(label='Verified'  description='Whether identity verification succeeded') public Boolean verified;
        @InvocableVariable(label='Order Id'  description='ID of the verified order')     public Id orderId;
        @InvocableVariable(label='Customer Tier' description='premium / standard') public String customerTier;
        @InvocableVariable(label='Attempts Used' description='Updated failure count')  public Integer attemptsUsed;
        @InvocableVariable(label='Message'
            description='Text that can be shown to the customer as is')                          public String message;
    }
}