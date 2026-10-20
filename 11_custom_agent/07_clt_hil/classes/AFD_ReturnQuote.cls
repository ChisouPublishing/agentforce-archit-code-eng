// Return quote (source type of the custom Lightning type c__returnQuote).
// Values shown on the screen card. Apex decides the amount and eligibility; the LLM never writes them.
@JsonAccess(serializable='always' deserializable='always')
global class AFD_ReturnQuote {
    @AuraEnabled global Boolean verified;
    @AuraEnabled global Boolean eligible;
    @AuraEnabled global String orderNumber;
    @AuraEnabled global Date orderDate;
    @AuraEnabled global String reasonLabel;
    @AuraEnabled global Decimal refundAmount;
    @AuraEnabled global Boolean needsApproval;  // over $100 becomes an approval request
    @AuraEnabled global String message;         // text that can be shown to the customer as is
}
