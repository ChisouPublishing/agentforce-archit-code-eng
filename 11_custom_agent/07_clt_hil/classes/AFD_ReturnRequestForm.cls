// Return request form (source type of the custom Lightning type c__returnRequestForm).
// The Apex type defines the input shape, so the values come from the form fields, not from what the LLM picks out of the conversation.
@JsonAccess(serializable='always' deserializable='always')
global class AFD_ReturnRequestForm {
    @AuraEnabled global String orderNumber;   // order number (8 digits)
    @AuraEnabled global String emailTail4;    // last 4 characters before the @ of the registered email
    @AuraEnabled global String reasonCode;    // DEFECT / WRONG_ITEM / SIZE / CHANGED_MIND
    @AuraEnabled global Boolean unopened;     // whether the customer declared the item unopened
}
