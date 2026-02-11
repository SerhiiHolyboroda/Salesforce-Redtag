public class OpportunityTriggerHandler {

    public static Boolean isActive = true;
    // BEFORE INSERT
    public void beforeInsert() {
      if (!isActive) return;
        System.debug('OpportunityTriggerHandler.beforeInsert called');
        validateCarRestrictions(Trigger.new, null);
    }

    // BEFORE UPDATE
    public void beforeUpdate() {

      if (!isActive) return;
        System.debug('OpportunityTriggerHandler.beforeInsert called');
        validateCarRestrictions(Trigger.new, null);
    }

    // BEFORE DELETE
    public void beforeDelete() {
        System.debug('OpportunityTriggerHandler.beforeDelete called');
    }

    // AFTER INSERT
    public void afterInsert() {
     System.debug('OpportunityTriggerHandler.afterInsert called');
      handleRelatedCars((List<Opportunity>)Trigger.new, (Map<Id, Opportunity>)null);
      updatePlannedSales(Trigger.newMap.keySet());
    }

    // AFTER UPDATE
    public void afterUpdate() {
        System.debug('OpportunityTriggerHandler.afterUpdate called');
        updatePlannedSales(Trigger.newMap.keySet());
        handleRelatedCars((List<Opportunity>)Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
    
    }

    // AFTER DELETE
    public void afterDelete() {
        System.debug('OpportunityTriggerHandler.afterDelete called');
        updatePlannedSales(Trigger.oldMap.keySet());
        handleRelatedCars((List<Opportunity>)Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
    }

    public void afterUndelete() {
        System.debug('OpportunityTriggerHandler.afterUndelete called');
    }
    

public static void updatePlannedSales(Set<Id> oppIds) {

    if (oppIds == null || oppIds.isEmpty()) return;

    // 1️⃣ Aggregate Closed Won Opportunities
 List<AggregateResult> results = [
    SELECT
        CALENDAR_YEAR(Opportunity.CloseDate) year,
        CALENDAR_MONTH(Opportunity.CloseDate) month,
        Product2.Car_Status__c carType,
        COUNT(Id) carsSold,
        SUM(TotalPrice) totalAmount
    FROM OpportunityLineItem
    WHERE OpportunityId IN (
        SELECT Id FROM Opportunity
        WHERE Id IN :oppIds
        AND StageName = 'Closed Won'
    )
    GROUP BY
        CALENDAR_YEAR(Opportunity.CloseDate),
        CALENDAR_MONTH(Opportunity.CloseDate),
        Product2.Car_Status__c
];


    // 2️⃣ Build map for fast lookup
    Map<String, AggregateResult> aggMap = new Map<String, AggregateResult>();
    for (AggregateResult ar : results) {
        String key = ar.get('year') + '-' + ar.get('month') + '-' + ar.get('carType');
        aggMap.put(key, ar);
    }

    // 3️⃣ Query existing Planned Sales
    List<Planned_Sales__c> plannedSales = [
        SELECT Id, Year__c, Month__c, Car_Type__c
        FROM Planned_Sales__c
    ];

    List<Planned_Sales__c> updates = new List<Planned_Sales__c>();

    // 4️⃣ Update or reset values
    for (Planned_Sales__c ps : plannedSales) {

        String key = ps.Year__c + '-' + ps.Month__c + '-' + ps.Car_Type__c;

        if (aggMap.containsKey(key)) {
            AggregateResult ar = aggMap.get(key);
            ps.Count_of_Cars_Sold__c = (Integer) ar.get('carsSold');
            ps.Total_Amount_Earned__c = (Decimal) ar.get('totalAmount');
        } else {
            ps.Count_of_Cars_Sold__c = 0;
            ps.Total_Amount_Earned__c = 0;
        }

        updates.add(ps);
    }

    if (!updates.isEmpty()) {
        update updates;
    }
}




public class PlannedSalesAccumulator {
    public Integer CarsSold = 0;
    public Decimal TotalAmount = 0;
}







    private void handleRelatedCars(List<Opportunity> opps, Map<Id, Opportunity> oldMap)  {
    if (opps == null || opps.isEmpty()) return;

    Set<Id> oppIds = new Set<Id>();
    for (Opportunity opp : opps) {
        Opportunity oldOpp = oldMap != null ? oldMap.get(opp.Id) : null;
        if (oldOpp == null || opp.StageName != oldOpp.StageName) {
            oppIds.add(opp.Id);
        }
    }
    if (oppIds.isEmpty()) return;

    List<OpportunityLineItem> olis = [
        SELECT Id, OpportunityId, Product2Id
        FROM OpportunityLineItem
        WHERE OpportunityId IN :oppIds
    ];

    if (olis.isEmpty()) return;

    Map<Id, Product2> oppToCar = new Map<Id, Product2>();
    Set<Id> carIds = new Set<Id>();
    for (OpportunityLineItem oli : olis) {
        carIds.add(oli.Product2Id);
        oppToCar.put(oli.OpportunityId, new Product2(Id = oli.Product2Id));
    }


    Map<Id, Product2> cars = new Map<Id, Product2>([
        SELECT Id, Car_Status__c, RecordTypeId
        FROM Product2
        WHERE Id IN :carIds
    ]);
    Map<String, Id> rtMap = new Map<String, Id>();
    for (RecordType rt : [SELECT Id, Name FROM RecordType WHERE SObjectType='Product2']) {
        rtMap.put(rt.Name, rt.Id);
    }

    List<Product2> carsToUpdate = new List<Product2>();
    for (Opportunity opp : opps) {
        if (!oppIds.contains(opp.Id)) continue;
        Product2 car = cars.get(oppToCar.get(opp.Id).Id);
        if (car == null) continue;

        String oldStage = oldMap != null && oldMap.containsKey(opp.Id) ? oldMap.get(opp.Id).StageName : null;
        String newStage = opp.StageName;

        if (newStage == 'Contract Sent') car.Car_Status__c = 'Reserved';
        else if (newStage == 'Closed Won') {
            car.Car_Status__c = 'Sold';
             if (rtMap.containsKey('Sold')) {
             car.RecordTypeId = rtMap.get('Sold');
    }
        }
        else if (newStage == 'Closed Lost') car.Car_Status__c = 'Available';
        else if (oldStage == 'Contract Sent' && newStage != 'Closed Won' && newStage != 'Closed Lost') car.Car_Status__c = 'Available';

        carsToUpdate.add(car);
    }

    if (!carsToUpdate.isEmpty()) update carsToUpdate;
}

private void validateCarRestrictions(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
        if (opps == null || opps.isEmpty()) return;

        Set<Id> oppIds = new Set<Id>();
        for (Opportunity opp : opps) oppIds.add(opp.Id);

        List<OpportunityLineItem> olis = [
            SELECT Id, OpportunityId, Product2Id
            FROM OpportunityLineItem
            WHERE OpportunityId IN :oppIds
        ];
        
        Set<Id> oppsWithOlis = new Set<Id>();
for (OpportunityLineItem oli : olis) {
    oppsWithOlis.add(oli.OpportunityId);
}

 
for (Opportunity opp : opps) {
    if (!oppsWithOlis.contains(opp.Id)) {
        opp.Has_Reserved_Cars__c = false;
    }
}

 
if (olis.isEmpty()) return;

        Set<Id> carIds = new Set<Id>();
        Map<Id, Id> oppToCar = new Map<Id, Id>();
        for (OpportunityLineItem oli : olis) {
            carIds.add(oli.Product2Id);
            oppToCar.put(oli.OpportunityId, oli.Product2Id);
        }

        Map<Id, Product2> cars = new Map<Id, Product2>([
            SELECT Id, Car_Status__c
            FROM Product2
            WHERE Id IN :carIds
        ]);

        for (Opportunity opp : opps) {
            List<String> warningCars = new List<String>();
            for (Id carId : oppToCar.values()) {
                Product2 car = cars.get(carId);
                if (car == null) continue;
   if (car == null) opp.Has_Reserved_Cars__c = false;
                if ((car.Car_Status__c == 'Reserved' || car.Car_Status__c == 'Sold') &&
                    (oldMap == null || !oldMap.containsKey(opp.Id) || opp.Id != oldMap.get(opp.Id).Id)) {
                    warningCars.add(car.Id);
                }



 
                if ((car.Car_Status__c == 'Available') && (opp.Has_Reserved_Cars__c == true) || (opp.OpportunityLineItems.isEmpty())) {
                 opp.Has_Reserved_Cars__c = false;
          
              }

                if (car.Car_Status__c == 'Sold') {
                    opp.addError('Warning! This Opportunity has reserved or sold cars. You are not able to move forward with it until you remove those cars or they are back available.');
                }
                if (car.Car_Status__c == 'Reserved') {
                    opp.Has_Reserved_Cars__c = true;
                    
                }
            }
        }
    }
}