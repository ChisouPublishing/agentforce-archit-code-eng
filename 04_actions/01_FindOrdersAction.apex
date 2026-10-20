public with sharing class FindOrdersAction {

    // Atlas uses label / description to choose tools. They are not comments for humans.
    @InvocableMethod(
        label='Find Orders'
        description='Returns orders from the last 90 days for a customer ID. If there are no matching orders, returns found=false and a reason instead of an empty list. This action does not accept returns or look up shipping status.'
        category='Order'
    )
    public static List<Result> findOrders(List<Request> requests) {
        List<Result> results = new List<Result>();
        if (requests == null) { return results; }

        // Agentforce calls one at a time, but query in bulk to handle bulk calls from Flow
        Set<Id> accountIds = new Set<Id>();
        for (Request r : requests) { if (r != null && r.accountId != null) { accountIds.add(r.accountId); } }

        Map<Id, List<Order>> byAccount = new Map<Id, List<Order>>();
        // Fetch up to 201 orders per account; the 201st tells us the list was truncated.
        for (Account account : [
            SELECT Id, (SELECT Id, OrderNumber, Status, EffectiveDate FROM Orders
                        WHERE EffectiveDate = LAST_N_DAYS:90
                        ORDER BY EffectiveDate DESC LIMIT 201)
            FROM Account WHERE Id IN :accountIds WITH USER_MODE
        ]) {
            List<Order> rows = new List<Order>();
            for (Order row : account.Orders) { rows.add(row); }
            byAccount.put(account.Id, rows);
        }

        for (Request r : requests) {
            Result res = new Result();
            List<Order> found = r == null ? null : byAccount.get(r.accountId);

            if (found == null || found.isEmpty()) {
                // This is the key point: return a state and a reason, not an empty result.
                // With an empty array, Atlas tends to read it as a failure and run the same action again.
                res.found  = false;
                res.reason = 'There are no orders in the last 90 days. If you are looking for an older order, I will connect you with a support representative.';
                res.summary = '';
            } else {
                res.found  = true;
                res.truncated = found.size() > 200;
                res.reason = res.truncated ? 'Showing the latest 200 orders. For older ones, please contact a support representative.' : '';
                // Do not return every field as JSON. It eats up the context, and the LLM handles a summarized text better.
                List<String> lines = new List<String>();
                for (Integer index = 0; index < Math.min(200, found.size()); index++) {
                    Order o = found[index];
                    lines.add(o.OrderNumber + ' / ' + o.Status + ' / ' + o.EffectiveDate.format());
                }
                res.summary = String.join(lines, '\n');
            }
            results.add(res);
        }
        return results;
    }

    public class Request {
        @InvocableVariable(
            required=true
            label='Account Id'
            description='ID of the account whose orders to search. Use the account linked to the user in the current conversation.')
        public Id accountId;
    }

    public class Result {
        @InvocableVariable public Boolean truncated = false;
        @InvocableVariable(label='Found' description='Whether any orders were found')
        public Boolean found;
        @InvocableVariable(label='Summary' description='List with one line per order: order number / status / order date')
        public String summary;
        @InvocableVariable(label='Reason' description='Reason when nothing was found or the list was truncated at the limit. Empty when all orders were returned')
        public String reason;
    }
}