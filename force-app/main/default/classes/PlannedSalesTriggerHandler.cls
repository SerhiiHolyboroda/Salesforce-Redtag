public class PlannedSalesTriggerHandler {

    public static void updatePlannedSalesFromOpportunities(List<Opportunity> opps) {
        Set<String> keys = new Set<String>();
        for(Opportunity o : opps) {
            if(o.StageName == 'Closed Won' || Trigger.isDelete) {
                for(OpportunityLineItem oli : [
                    SELECT Product2Id, Product2.Car_Status__c, Quantity, TotalPrice
                    FROM OpportunityLineItem
                    WHERE OpportunityId = :o.Id
                ]) {
                    String key = o.CloseDate.year() + '-' + o.CloseDate.month() + '-' + oli.Product2.Car_Status__c;
                    keys.add(key);
                }
            }
        }

        if(keys.isEmpty()) return;

        List<Planned_Sales__c> plannedSales = [
            SELECT Id, Year__c, Month__c, Car_Type__c
            FROM Planned_Sales__c
        ];

        recalculatePlannedSales(plannedSales);
    }

    public static void recalculatePlannedSales(List<Planned_Sales__c> plannedSales) {
        Map<String, Planned_Sales__c> psMap = new Map<String, Planned_Sales__c>();
        for(Planned_Sales__c ps : plannedSales) {
            String key = ps.Year__c + '-' + ps.Month__c + '-' + ps.Car_Type__c;
            psMap.put(key, ps);
        }

        List<OpportunityLineItem> olis = [
            SELECT Opportunity.CloseDate, Opportunity.StageName,
           // Product2.Car_Type__c, 
            Quantity, TotalPrice
            FROM OpportunityLineItem
            WHERE Opportunity.StageName = 'Closed Won'
        ];

        Map<String, Integer> carsSold = new Map<String, Integer>();
        Map<String, Decimal> totalEarned = new Map<String, Decimal>();

        for(OpportunityLineItem oli : olis) {
            String key = oli.Opportunity.CloseDate.year() + '-' + oli.Opportunity.CloseDate.month() + '-' + oli.Product2.Car_Status__c;
            carsSold.put(key, (carsSold.containsKey(key) ? carsSold.get(key) : 0) + Integer.valueOf(oli.Quantity));
            totalEarned.put(key, (totalEarned.containsKey(key) ? totalEarned.get(key) : 0) + oli.TotalPrice);
        }

        List<Planned_Sales__c> psToUpdate = new List<Planned_Sales__c>();
        for(String key : psMap.keySet()) {
            Planned_Sales__c ps = psMap.get(key);
            ps.Count_of_Cars_Sold__c = carsSold.containsKey(key) ? carsSold.get(key) : 0;
            ps.Total_Amount_Earned__c = totalEarned.containsKey(key) ? totalEarned.get(key) : 0;
            psToUpdate.add(ps);
        }

        if(!psToUpdate.isEmpty()) {
            try {
                update psToUpdate;
            } catch(DmlException e) {
                System.debug('Error updating Planned Sales: ' + e.getMessage());
            }
        }
    }
}