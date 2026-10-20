global with sharing class AFD_ListReturnableOrdersAction {

    @InvocableMethod(label='List Returnable Orders'
        description='Returns the orders of the verified customer from the last 90 days as a list of cards, each marked with whether it can be returned. Does not process a return.')
    global static List<Result> listOrders(List<Request> reqs) {
        List<Result> out = new List<Result>();
        if (reqs == null) { return out; }
        Date earliest = Date.today().addDays(-30);
        for (Request r : reqs) {
            Result res = new Result();
            res.orders = new List<AFD_OrderCard>();
            List<Order> me = r == null || r.orderId == null ? new List<Order>()
                : [SELECT AccountId FROM Order WHERE Id = :r.orderId WITH USER_MODE LIMIT 1];
            if (me.isEmpty()) { res.summary = 'We could not find the order.'; out.add(res); continue; }
            Set<Id> requested = new Set<Id>();
            List<Order> rows = [SELECT Id, OrderNumber, EffectiveDate, TotalAmount, Is_Opened__c FROM Order
                                WHERE AccountId = :me[0].AccountId AND EffectiveDate = LAST_N_DAYS:90
                                WITH USER_MODE ORDER BY EffectiveDate DESC, OrderNumber LIMIT 20];
            for (Refund__c rf : [SELECT Order__c FROM Refund__c WHERE Order__r.AccountId = :me[0].AccountId WITH USER_MODE]) {
                requested.add(rf.Order__c);
            }
            List<String> lines = new List<String>();
            for (Order o : rows) {
                AFD_OrderCard c = new AFD_OrderCard();
                c.orderNumber = o.OrderNumber; c.orderDate = o.EffectiveDate;
                c.totalAmount = o.TotalAmount; c.opened = o.Is_Opened__c;
                c.returnable = !o.Is_Opened__c && !requested.contains(o.Id)
                    && o.EffectiveDate >= earliest && o.TotalAmount != null && o.TotalAmount > 0;
                c.note = requested.contains(o.Id) ? 'Already requested'
                    : o.Is_Opened__c ? 'Opened' : o.EffectiveDate < earliest ? 'Over 30 days'
                    : (o.TotalAmount == null || o.TotalAmount <= 0) ? 'No amount' : 'Returnable';
                res.orders.add(c);
                lines.add(o.OrderNumber + ' / ' + c.note);
            }
            // Pass only a short summary to the LLM. The card content is shown on screen only
            res.summary = String.join(lines, '\n');
            out.add(res);
        }
        return out;
    }

    global class Request {
        @InvocableVariable(required=true label='Order Id'
            description='ID of the order identified during identity verification. Passed from a conversation variable.') global Id orderId;
    }
    global class Result {
        @InvocableVariable(label='Orders' description='Order cards shown on screen') global List<AFD_OrderCard> orders;
        @InvocableVariable(label='Summary' description='Summary with one line per order: order number and whether it can be returned') global String summary;
    }
}
