trigger OpportunityTrigger on Opportunity ( 
    before insert,
    before update,
    before delete,
    after insert,
    after update,
    after delete,
    after undelete
) {
    OpportunityTriggerHandler handler = new OpportunityTriggerHandler();

    if (Trigger.isBefore) {
        if (Trigger.isInsert) handler.beforeInsert();
        if (Trigger.isUpdate) handler.beforeUpdate();
        if (Trigger.isDelete) handler.beforeDelete();
    }

    if (Trigger.isAfter) {
        if (Trigger.isInsert) handler.afterInsert();
        if (Trigger.isUpdate) handler.afterUpdate();
        if (Trigger.isDelete) handler.afterDelete();
        if (Trigger.isUndelete) handler.afterUndelete();
    }
}