// Input of the confirm button (source type of the custom Lightning type c__returnConfirmation).
// Only the form checkbox can set confirmed to true. It is not a value the LLM fills in by reading "yes".
@JsonAccess(serializable='always' deserializable='always')
global class AFD_ReturnConfirmation {
    @AuraEnabled global String orderNumber;
    @AuraEnabled global Decimal refundAmount;
    @AuraEnabled global Boolean confirmed;
}
