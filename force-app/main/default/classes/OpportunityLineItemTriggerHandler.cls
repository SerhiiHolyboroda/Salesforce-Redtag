public with sharing class OpportunityLineItemTriggerHandler {
    public static void enforceQuantityOne(List<OpportunityLineItem> oliList) {
        for (OpportunityLineItem oli : oliList) {
            if (oli.Quantity != 1) {
                oli.addError('Quantity must be 1. Each car must be tracked individually.');
            }
        }
    }
}