@IsTest
private class AFD_ReturnFormActionsTest {

    // ---- Test data: billing email demo1234@example.com, an unopened $30 order
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Form Test', Membership_Tier__c = 'Premium');
        insert acc;
        Contact con = new Contact(LastName = 'Buyer', AccountId = acc.Id, Email = 'demo1234@example.com');
        insert con;
        Product2 item = new Product2(Name = 'Form Test Item', IsActive = true);
        insert item;
        PricebookEntry price = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = item.Id, UnitPrice = 30, IsActive = true);
        insert price;
        Order o = new Order(AccountId = acc.Id, BillToContactId = con.Id, Status = 'Draft',
            EffectiveDate = Date.today().addDays(-3), Pricebook2Id = Test.getStandardPricebookId());
        insert o;
        insert new OrderItem(OrderId = o.Id, PricebookEntryId = price.Id, Quantity = 1, UnitPrice = 30);
    }

    private static Order theOrder() {
        return [SELECT Id, OrderNumber, TotalAmount FROM Order LIMIT 1];
    }

    private static AFD_PrepareReturnQuoteAction.Result prepare(String tail4, String reason, Boolean unopened) {
        AFD_ReturnRequestForm f = new AFD_ReturnRequestForm();
        f.orderNumber = theOrder().OrderNumber; f.emailTail4 = tail4;
        f.reasonCode = reason; f.unopened = unopened;
        AFD_PrepareReturnQuoteAction.Request r = new AFD_PrepareReturnQuoteAction.Request();
        r.request = f;
        return AFD_PrepareReturnQuoteAction.prepare(new List<AFD_PrepareReturnQuoteAction.Request>{ r })[0];
    }

    private static AFD_SubmitReturnRequestAction.Result submit(Id orderId, Decimal amount, Boolean confirmed, Decimal shown) {
        AFD_ReturnConfirmation c = new AFD_ReturnConfirmation();
        c.confirmed = confirmed; c.refundAmount = shown;
        AFD_SubmitReturnRequestAction.Request r = new AFD_SubmitReturnRequestAction.Request();
        r.orderId = orderId; r.amount = amount; r.confirmation = c;
        return AFD_SubmitReturnRequestAction.submit(new List<AFD_SubmitReturnRequestAction.Request>{ r })[0];
    }

    @IsTest
    static void quoteIsBuiltFromTheFormAndExistingRules() {
        AFD_PrepareReturnQuoteAction.Result res = prepare('1234', 'SIZE', true);
        System.assertEquals(true, res.verified);
        System.assertEquals(true, res.eligible);
        System.assertEquals(30, res.refundAmount, 'Apex decides the amount from the order');
        System.assertEquals(false, res.needsApproval);
        System.assertEquals('Wrong size or specifications', res.quote.reasonLabel);
        System.assertEquals(theOrder().Id, res.orderId);
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c], 'Building the quote writes nothing');
        String cited = JSON.serialize(res.citations);
        System.assert(cited.contains('/lightning/r/Order/' + theOrder().Id + '/view'), 'Cites the order used for the decision: ' + cited);
    }

    @IsTest
    static void incompleteFormIsRejectedWithoutGuessing() {
        AFD_PrepareReturnQuoteAction.Result res = prepare('1234', 'UNKNOWN', true);
        System.assertEquals(false, res.verified);
        System.assertEquals('Required fields in the form are missing.', res.message);
        res = prepare('1234', 'SIZE', null);
        System.assertEquals(false, res.eligible);
    }

    @IsTest
    static void wrongEmailAndDeclaredOpenedAreNotEligible() {
        AFD_PrepareReturnQuoteAction.Result wrong = prepare('9999', 'SIZE', true);
        System.assertEquals(false, wrong.verified);
        System.assertEquals(null, wrong.orderId);
        System.assertEquals(null, wrong.citations, 'No citation when identity verification fails (do not reveal that the order exists)');
        AFD_PrepareReturnQuoteAction.Result opened = prepare('1234', 'DEFECT', false);
        System.assertEquals(true, opened.verified);
        System.assertEquals(false, opened.eligible);
        System.assertEquals(0, opened.refundAmount);
    }

    @IsTest
    static void submitDoesNothingWithoutTheConfirmButton() {
        Order o = theOrder();
        AFD_SubmitReturnRequestAction.Result res = submit(o.Id, 30, false, 30);
        System.assertEquals(false, res.submitted);
        res = submit(o.Id, 30, null, 30);
        System.assertEquals(false, res.submitted);
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c]);
    }

    @IsTest
    static void submitStopsWhenShownAmountDiffers() {
        AFD_SubmitReturnRequestAction.Result res = submit(theOrder().Id, 30, true, 25);
        System.assertEquals(false, res.submitted);
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c]);
    }

    @IsTest
    static void confirmedSubmitCreatesOneRefund() {
        Order o = theOrder();
        // A refund request queues the payment callout asynchronously. The test mocks the callout
        Test.setMock(HttpCalloutMock.class, new GatewayMock());
        Test.startTest();
        AFD_SubmitReturnRequestAction.Result res = submit(o.Id, 30, true, 30);
        AFD_SubmitReturnRequestAction.Result again = submit(o.Id, 30, true, 30);
        Test.stopTest();
        System.assertEquals(true, res.submitted);
        System.assertEquals(true, again.submitted, 'The second call returns the existing request');
        System.assertEquals(1, [SELECT COUNT() FROM Refund__c WHERE Order__c = :o.Id]);
        Refund__c rec = [SELECT Id FROM Refund__c WHERE Order__c = :o.Id];
        System.assert(JSON.serialize(res.citations).contains('/lightning/r/Refund__c/' + rec.Id + '/view'), 'Cites the refund that was created');
    }

    @IsTest
    static void largeAmountBecomesApprovalRequest() {
        Order o = theOrder();
        AFD_SubmitReturnRequestAction.Result res = submit(o.Id, 150, true, 150);
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c WHERE Status__c = 'Requested'],
            'Amounts over $100 do not become refund requests');
        System.assertNotEquals(null, res.message);
    }

    @IsTest
    static void orderListMarksReturnableOrders() {
        AFD_ListReturnableOrdersAction.Request r = new AFD_ListReturnableOrdersAction.Request();
        r.orderId = theOrder().Id;
        AFD_ListReturnableOrdersAction.Result res =
            AFD_ListReturnableOrdersAction.listOrders(new List<AFD_ListReturnableOrdersAction.Request>{ r })[0];
        System.assertEquals(1, res.orders.size());
        System.assertEquals(true, res.orders[0].returnable);
        System.assertEquals('Returnable', res.orders[0].note);
        System.assert(res.summary.contains(theOrder().OrderNumber));
    }

    private class GatewayMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse r = new HttpResponse();
            r.setStatusCode(202);
            r.setBody('{"status":"accepted"}');
            return r;
        }
    }
}
