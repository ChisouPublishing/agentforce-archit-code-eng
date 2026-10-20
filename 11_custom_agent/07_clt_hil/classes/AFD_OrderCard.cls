// One card in the order list (source type of the custom Lightning type c__orderCard; the list is drawn by a collection renderer).
@JsonAccess(serializable='always' deserializable='always')
global class AFD_OrderCard {
    @AuraEnabled global String orderNumber;
    @AuraEnabled global Date orderDate;
    @AuraEnabled global Decimal totalAmount;
    @AuraEnabled global Boolean opened;
    @AuraEnabled global Boolean returnable;
    @AuraEnabled global String note;
}
