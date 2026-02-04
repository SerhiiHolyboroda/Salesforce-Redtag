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
    }

    // AFTER UPDATE
    public void afterUpdate() {
        System.debug('OpportunityTriggerHandler.afterUpdate called');
        updatePlannedSales((List<Opportunity>)Trigger.old, (Map<Id, Opportunity>)Trigger.oldMap);
        handleRelatedCars((List<Opportunity>)Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
    
    }

    // AFTER DELETE
    public void afterDelete() {
        System.debug('OpportunityTriggerHandler.afterDelete called');
        updatePlannedSales((List<Opportunity>)Trigger.old, (Map<Id, Opportunity>)Trigger.oldMap);
        handleRelatedCars((List<Opportunity>)Trigger.new, (Map<Id, Opportunity>)Trigger.oldMap);
    }

    public void afterUndelete() {
        System.debug('OpportunityTriggerHandler.afterUndelete called');
    }
    

public void updatePlannedSales(List<Opportunity> opps, Map<Id, Opportunity> oldMap) {
    if (!isActive || opps == null || opps.isEmpty()) return;


    Set<Id> relevantOppIds = new Set<Id>();
    for (Opportunity opp : opps) {
        String oldStage = (oldMap != null && oldMap.containsKey(opp.Id)) ? oldMap.get(opp.Id).StageName : null;
        String newStage = opp.StageName;

        if ((newStage == 'Closed Won' )) {
            relevantOppIds.add(opp.Id);
        }
    }
    if (relevantOppIds.isEmpty()) return;


    List<OpportunityLineItem> olis = [
        SELECT Id, OpportunityId, Product2Id, TotalPrice
        FROM OpportunityLineItem
        WHERE OpportunityId IN :relevantOppIds
    ];
    if (olis.isEmpty()) return;


    Set<Id> productIds = new Set<Id>();
    for (OpportunityLineItem oli : olis) productIds.add(oli.Product2Id);

    Map<Id, Product2> products = new Map<Id, Product2>([
        SELECT Id, Car_Status__c
        FROM Product2
        WHERE Id IN :productIds
    ]);

    Map<Id, Opportunity> oppMap = new Map<Id, Opportunity>(opps);

    Map<String, PlannedSalesAccumulator> psAccMap = new Map<String, PlannedSalesAccumulator>();
    for (OpportunityLineItem oli : olis) {
        Opportunity opp = oppMap.get(oli.OpportunityId);
        if (opp == null) continue;

        Product2 prod = products.get(oli.Product2Id);
        if (prod == null || prod.Car_Status__c == null) continue;

        String key = opp.CloseDate.year() + '-' + opp.CloseDate.month() + '-' + prod.Car_Status__c;

        if (!psAccMap.containsKey(key)) psAccMap.put(key, new PlannedSalesAccumulator());
        PlannedSalesAccumulator acc = psAccMap.get(key);

        String oldStage = (oldMap != null && oldMap.containsKey(opp.Id)) ? oldMap.get(opp.Id).StageName : null;
        String newStage = opp.StageName;

        // Adjust totals based on stage change
        if (newStage == 'Closed Won' && oldStage != 'Closed Won') {
            acc.CarsSold += 1;
            acc.TotalAmount += (oli.TotalPrice != null) ? oli.TotalPrice : 0;
        } else if (oldStage == 'Closed Won' && newStage != 'Closed Won') {
            acc.CarsSold -= 1;
            acc.TotalAmount -= (oli.TotalPrice != null) ? oli.TotalPrice : 0;
        }
    }

    if (psAccMap.isEmpty()) return;

    // 6. Query existing Planned Sales records in bulk
    Set<Integer> years = new Set<Integer>();
    Set<Integer> months = new Set<Integer>();
    Set<String> carTypes = new Set<String>();
    for (String key : psAccMap.keySet()) {
        String[] parts = key.split('-');
        years.add(Integer.valueOf(parts[0]));
        months.add(Integer.valueOf(parts[1]));
        carTypes.add(parts[2]);
    }

    Map<String, Planned_Sales__c> existingPSMap = new Map<String, Planned_Sales__c>();
    for (Planned_Sales__c ps : [
        SELECT Id, Year__c, Month__c, Car_Type__c, Count_of_Cars_Sold__c, Total_Amount_Earned__c
        FROM Planned_Sales__c
        WHERE Year__c IN :years AND Month__c IN :months AND Car_Type__c IN :carTypes
    ]) {
        String key = ps.Year__c + '-' + ps.Month__c + '-' + ps.Car_Type__c;
        existingPSMap.put(key, ps);
    }

    List<Planned_Sales__c> plannedSalesToUpsert = new List<Planned_Sales__c>();
    for (String key : psAccMap.keySet()) {
        String[] parts = key.split('-');
        Integer year = Integer.valueOf(parts[0]);
        Integer month = Integer.valueOf(parts[1]);
        String carType = parts[2];

        PlannedSalesAccumulator acc = psAccMap.get(key);

        if (existingPSMap.containsKey(key)) {
            Planned_Sales__c ps = existingPSMap.get(key);
            ps.Count_of_Cars_Sold__c += acc.CarsSold;
            ps.Total_Amount_Earned__c += acc.TotalAmount;
            plannedSalesToUpsert.add(ps);
        } else {
            plannedSalesToUpsert.add(new Planned_Sales__c(
                Year__c = year,
                Month__c = month,
                Car_Type__c = carType,
                Count_of_Cars_Sold__c = acc.CarsSold,
                Total_Amount_Earned__c = acc.TotalAmount
            ));
        }
    }

    if (!plannedSalesToUpsert.isEmpty()) {
        try {
            upsert plannedSalesToUpsert;
        } catch (DmlException e) {
            System.debug('Error updating Planned Sales: ' + e.getMessage());
        }
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

                if ((car.Car_Status__c == 'Reserved' || car.Car_Status__c == 'Sold') &&
                    (oldMap == null || !oldMap.containsKey(opp.Id) || opp.Id != oldMap.get(opp.Id).Id)) {
                    warningCars.add(car.Id);
                }



                if ((car.Car_Status__c == 'Available') && (opp.Has_Reserved_Cars__c == true)) {
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
