trigger OpportunityLineItemTrigger on OpportunityLineItem (
    before insert,
    before update
) {
    OpportunityLineItemTriggerHandler.enforceQuantityOne(Trigger.new);
}