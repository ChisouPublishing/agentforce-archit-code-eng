@IsTest
private class ReturnRefundActionsTest {

    // ---- Test data: membership tier Premium, billing email demo1234@example.com, a $30 order
    @TestSetup
    static void setup() {
        Account acc = new Account(Name = 'Return Test', Membership_Tier__c = 'Premium');
        insert acc;
        Contact con = new Contact(LastName = 'Buyer', AccountId = acc.Id, Email = 'demo1234@example.com');
        insert con;
        Product2 item = new Product2(Name = 'Return Test Item', IsActive = true);
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

    // ---- Identity verification
    @IsTest
    static void verifySucceedsOnlyWithMatchingEmailTail() {
        VerifyCustomerAction.Request req = new VerifyCustomerAction.Request();
        req.orderNumber = theOrder().OrderNumber;
        req.emailTail4 = '1234';
        VerifyCustomerAction.Result ok = VerifyCustomerAction.verify(
            new List<VerifyCustomerAction.Request>{ req })[0];
        System.assertEquals(true, ok.verified);
        System.assertEquals('premium', ok.customerTier);
        System.assertEquals(0, ok.attemptsUsed, 'Success does not increase the failure count');

        req.emailTail4 = '9999';
        VerifyCustomerAction.Result ng = VerifyCustomerAction.verify(
            new List<VerifyCustomerAction.Request>{ req })[0];
        System.assertEquals(false, ng.verified);
        System.assertEquals(null, ng.orderId, 'No order ID is returned on failure');
        System.assertEquals(1, ng.attemptsUsed);
    }

    @IsTest
    static void verifyStopsAfterThreeFailures() {
        VerifyCustomerAction.Request req = new VerifyCustomerAction.Request();
        req.orderNumber = theOrder().OrderNumber;
        req.emailTail4 = '1234';       // Even a correct value is not checked once the limit is reached
        req.previousAttempts = 3;
        VerifyCustomerAction.Result res = VerifyCustomerAction.verify(
            new List<VerifyCustomerAction.Request>{ req })[0];
        System.assertEquals(false, res.verified);
        System.assertEquals(3, res.attemptsUsed);
    }

    // ---- Return eligibility
    @IsTest
    static void eligibilityFollowsTheReturnPolicy() {
        Order o = theOrder();
        CheckReturnEligibilityAction.Result ok = eligibility(o.Id);
        System.assertEquals(true, ok.eligible);
        System.assertEquals(30, ok.refundAmount, 'Expected refund amount equals the order total');

        update new Order(Id = o.Id, Is_Opened__c = true);
        System.assertEquals(false, eligibility(o.Id).eligible, 'Opened items are not eligible');

        update new Order(Id = o.Id, Is_Opened__c = false, EffectiveDate = Date.today().addDays(-31));
        System.assertEquals(false, eligibility(o.Id).eligible, 'A purchase 31 days ago is not eligible');

        update new Order(Id = o.Id, EffectiveDate = Date.today().addDays(-30));
        System.assertEquals(true, eligibility(o.Id).eligible, 'A purchase exactly 30 days ago is still eligible');
    }

    @IsTest
    static void eligibilityIsBulkSafe() {
        Id orderId = theOrder().Id;
        List<CheckReturnEligibilityAction.Request> reqs = new List<CheckReturnEligibilityAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            CheckReturnEligibilityAction.Request r = new CheckReturnEligibilityAction.Request();
            r.orderId = orderId;
            reqs.add(r);
        }
        Integer before = Limits.getQueries();
        List<CheckReturnEligibilityAction.Result> results = CheckReturnEligibilityAction.check(reqs);
        System.assertEquals(2, Limits.getQueries() - before, '2 SOQL queries regardless of the number of requests');
        System.assertEquals(200, results.size());
    }

    // ---- Refund ($100 or less)
    @IsTest
    static void refundIsAcceptedOnceAndIsIdempotent() {
        Order o = theOrder();
        Test.setMock(HttpCalloutMock.class, new GatewayMock(202));
        Test.startTest();
        ExecuteRefundAction.Result first = refund(o.Id, 30);
        ExecuteRefundAction.Result second = refund(o.Id, 30);   // Simulates the agent running it again
        ExecuteRefundAction.Result changed = refund(o.Id, 20);  // Same order, different amount
        Test.stopTest();

        System.assertEquals(true, first.succeeded);
        System.assertEquals(true, second.succeeded);
        System.assertEquals(true, second.alreadyProcessed);
        System.assertEquals(false, changed.succeeded);
        List<Refund__c> rows = [SELECT Status__c, Idempotency_Key__c FROM Refund__c];
        System.assertEquals(1, rows.size(), 'Only one refund record');
        System.assertEquals('REFUND:' + o.Id, rows[0].Idempotency_Key__c);
        System.assertEquals('Submitted', rows[0].Status__c, 'The asynchronous payment call succeeded');
        System.assertEquals(false, eligibility(o.Id).eligible, 'After the refund, a new eligibility check returns not eligible');
    }

    @IsTest
    static void refundGuardsAmountEvenIfAgentGuardIsBypassed() {
        Id orderId = theOrder().Id;
        for (Decimal amount : new List<Decimal>{ null, 0, -1, 30.01, 100.01 }) {
            System.assertEquals(false, refund(orderId, amount).succeeded, 'Amount ' + amount);
        }
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c]);
    }

    @IsTest
    static void refundRejectsBulkAndDoesNotReportFailedRequestAsSuccess() {
        Id orderId = theOrder().Id;
        List<ExecuteRefundAction.Request> batchReqs = new List<ExecuteRefundAction.Request>();
        for (Integer i = 0; i < 200; i++) {
            ExecuteRefundAction.Request r = new ExecuteRefundAction.Request();
            r.orderId = orderId;
            r.amount = 1;
            batchReqs.add(r);
        }
        List<ExecuteRefundAction.Result> results = ExecuteRefundAction.run(batchReqs);
        System.assertEquals(200, results.size(), 'Bulk input returns one result per request');
        System.assertEquals(false, results[0].succeeded, 'Bulk refunds are sent for review by a support representative');
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c]);

        // A refund that failed payment and needs review is not reported as a success on retry
        insert new Refund__c(Order__c = orderId, Amount__c = 30, Status__c = 'NeedsReview',
            Idempotency_Key__c = 'REFUND:' + orderId);
        ExecuteRefundAction.Result retry = refund(orderId, 30);
        System.assertEquals(false, retry.succeeded);
        System.assertEquals(true, retry.alreadyProcessed);
    }

    // ---- Approval request (over $100)
    @IsTest
    static void approvalRequestIsCreatedOnce() {
        Order o = theOrder();
        CreateApprovalRequestAction.Result tooMuch = approval(o.Id, 9999.99);
        System.assertEquals(false, tooMuch.created, 'An amount over the order total is not requested');
        System.assertEquals(null, tooMuch.requestNumber);

        CreateApprovalRequestAction.Result first = approval(o.Id, 30);
        CreateApprovalRequestAction.Result second = approval(o.Id, 30);
        System.assertEquals(true, first.created);
        System.assert(first.requestNumber.startsWith('BR-'), first.requestNumber);
        System.assertEquals(false, second.created);
        System.assertEquals(first.requestNumber, second.requestNumber, 'The second call returns the existing request number');
        System.assertEquals('PendingApproval', [SELECT Status__c FROM Refund__c].Status__c);
    }

    // ---- Running user permissions: actions run with the running user's permissions (USER_MODE)
    @IsTest
    static void userWithoutPermissionGetsMessageNotException() {
        Id orderId = theOrder().Id;
        User noAccess = newUser(false);
        System.runAs(noAccess) {
            ExecuteRefundAction.Result res = refund(orderId, 30);
            System.assertEquals(false, res.succeeded);
            System.assertNotEquals(null, res.message, 'A safe message is returned instead of an exception');
        }
        System.assertEquals(0, [SELECT COUNT() FROM Refund__c]);
    }

    @IsTest
    static void agentPermissionSetIsSufficient() {
        Id orderId = theOrder().Id;
        User agent = newUser(true);
        Test.setMock(HttpCalloutMock.class, new GatewayMock(202));
        System.runAs(agent) {
            Test.startTest();
            System.assertEquals(true, eligibility(orderId).eligible);
            System.assertEquals(true, refund(orderId, 30).succeeded);
            Test.stopTest();
        }
        System.assertEquals(1, [SELECT COUNT() FROM Refund__c]);
    }

    // ---- Helpers
    private static CheckReturnEligibilityAction.Result eligibility(Id orderId) {
        CheckReturnEligibilityAction.Request r = new CheckReturnEligibilityAction.Request();
        r.orderId = orderId;
        return CheckReturnEligibilityAction.check(new List<CheckReturnEligibilityAction.Request>{ r })[0];
    }
    private static ExecuteRefundAction.Result refund(Id orderId, Decimal amount) {
        ExecuteRefundAction.Request r = new ExecuteRefundAction.Request();
        r.orderId = orderId;
        r.amount = amount;
        return ExecuteRefundAction.run(new List<ExecuteRefundAction.Request>{ r })[0];
    }
    private static CreateApprovalRequestAction.Result approval(Id orderId, Decimal amount) {
        CreateApprovalRequestAction.Request r = new CreateApprovalRequestAction.Request();
        r.orderId = orderId;
        r.amount = amount;
        return CreateApprovalRequestAction.create(new List<CreateApprovalRequestAction.Request>{ r })[0];
    }

    // User with a minimum-access profile. With withAgentPermissions, assigns the agent's permission set
    private static User newUser(Boolean withAgentPermissions) {
        Profile p = [SELECT Id FROM Profile WHERE UserType = 'Standard'
                     AND PermissionsModifyAllData = false AND PermissionsViewAllData = false
                     ORDER BY CreatedDate LIMIT 1];
        String unique = String.valueOf(Crypto.getRandomInteger()).replace('-', '');
        User u = new User(ProfileId = p.Id, LastName = 'Agent Test',
            Username = 'agent.test.' + unique + '@example.com', Email = 'agent.test@example.com',
            Alias = 'agtest', TimeZoneSidKey = 'America/New_York', LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8', LanguageLocaleKey = 'en_US');
        insert u;
        if (withAgentPermissions) {
            Id ps = [SELECT Id FROM PermissionSet WHERE Name = 'ReturnRefundAgent'].Id;
            insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = ps);
        }
        return u;
    }

    private class GatewayMock implements HttpCalloutMock {
        private Integer status;
        GatewayMock(Integer status) { this.status = status; }
        public HttpResponse respond(HttpRequest req) {
            System.assertNotEquals(null, req.getHeader('Idempotency-Key'), 'The idempotency key is also sent to the payment gateway');
            HttpResponse res = new HttpResponse();
            res.setStatusCode(status);
            res.setBody('{}');
            return res;
        }
    }
}