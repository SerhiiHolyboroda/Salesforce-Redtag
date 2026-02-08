@IsTest
public class TestDataFactory {

    public static Account createAccount() {
       Database.DMLOptions dmlOpts = new Database.DMLOptions();
        dmlOpts.DuplicateRuleHeader.allowSave = true;
        Account acc = new Account(
      // RecordTypeId = businessRtId,
        Name = 'Test Account',
        BillingCountry = 'Ukraine',
        BillingStreet = '123 Main Street',
        BillingCity = 'Kyiv',
       // BillingState = 'Kyiv City',
        BillingPostalCode = '01001'
        
        // ShippingStreet = '123 Main Street',
        // ShippingCity = 'Kyiv',
        // ShippingState = 'Kyiv City',
        // ShippingPostalCode = '01001',
        // ShippingCountry = 'Ukraine',
        // Phone = '+380441234567',
        // Fax = '+380441234568',
        // Website = 'https://www.testaccount.com',
        // Industry = 'Technology',
        // NumberOfEmployees = 50,
        // AnnualRevenue = 1000000
    );
       Database.insert(acc, dmlOpts);
        return acc;
    }

    public static Id getStandardPricebook() {
        //return [SELECT Id FROM Pricebook2 WHERE IsStandard = true LIMIT 1];
         Id stdPbId = Test.getStandardPricebookId();
       //   return [SELECT Id FROM Pricebook2 WHERE Id = :stdPbId];
       return stdPbId;
    }

    public static List<Product2> createCars(Integer count, String status, String typeValue) {
        List<Product2> cars = new List<Product2>();
        for (Integer i = 0; i < count; i++) {
            cars.add(new Product2(
                Name = 'Car ' + i,
                IsActive = true,
                Car_Status__c = status,
                Model__c = 'BMW',
	            Mileage__c = 124,
                Brand__c = 'BMW',
                VIN_Number__c = 'Car ' + i + 1
              //  Type = typeValue
            ));
        }
        insert cars;
        return cars;
    }

    public static List<PricebookEntry> createPBEs(List<Product2> products) {
        Id pb =  getStandardPricebook();
        //getStandardPricebook();
        List<PricebookEntry> entries = new List<PricebookEntry>();
        for (Product2 p : products) {
            entries.add(new PricebookEntry(
                Pricebook2Id = pb,
                Product2Id = p.Id,
                UnitPrice = 10000,
                IsActive = true
            ));
        }
        insert entries;
        return entries;
    }

    public static List<Opportunity> createOpportunities(Account acc, Integer count, String stage) {
        List<Opportunity> opps = new List<Opportunity>();
        for (Integer i = 0; i < count; i++) {
            opps.add(new Opportunity(
                Name = 'Opp ' + i,
                AccountId = acc.Id,
                StageName = stage,
                CloseDate = Date.today().addDays(30),
                Has_Reserved_Cars__c = false
            ));
        }
        insert opps;
        return opps;
    }

    public static List<OpportunityLineItem> createOLIs(
        List<Opportunity> opps,
        List<PricebookEntry> pbes,
        Integer quantity
    ) {
        List<OpportunityLineItem> olis = new List<OpportunityLineItem>();
        Integer idx = 0;
        for (Opportunity o : opps) {
            olis.add(new OpportunityLineItem(
                OpportunityId = o.Id,
                PricebookEntryId = pbes[idx].Id,
                Quantity = quantity,
                TotalPrice = 10000
            ));
            idx++;
        }
        insert olis;
        return olis;
    }
}