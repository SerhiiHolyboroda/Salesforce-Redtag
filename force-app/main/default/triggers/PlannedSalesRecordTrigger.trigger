trigger PlannedSalesRecordTrigger on Planned_Sales__c (after insert, after update) {
   // if(!TriggerHelper.isTriggerEnabled('Planned_Sales')) return;

    try {
        if(Trigger.isAfter) {
            PlannedSalesTriggerHandler.recalculatePlannedSales(Trigger.new);
        }
    } catch(Exception e) {
        System.debug('Error in PlannedSalesRecordTrigger: ' + e.getMessage());
    }
}