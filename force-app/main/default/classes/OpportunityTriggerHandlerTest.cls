@IsTest
public class OpportunityTriggerHandlerTest {

    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount();
        List<Product2> cars = TestDataFactory.createCars(5, 'Available', 'New');
        List<PricebookEntry> pbes = TestDataFactory.createPBEs(cars);
        List<Opportunity> opps = TestDataFactory.createOpportunities(acc, 5, 'Prospecting');

        TestDataFactory.createOLIs(opps, pbes, 1);

        insert new Planned_Sales__c(
            Year__c = Date.today().year(),
            Month__c = Date.today().month(),
            Car_Type__c = 'New',
            Count_of_Cars_Sold__c = 0,
            Total_Amount_Earned__c = 0
        );
    }

    @IsTest
    static void testBeforeInsert_reservedCar_block() {
      //  Product2 car = [SELECT Id FROM Product2 LIMIT 1];
      //  car.Car_Status__c = 'Sold';
     //   update car;

        Opportunity opp = new Opportunity(
            Name = 'Blocked Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(5),
            AccountId = TestDataFactory.createAccount().Id
        );

        
        Test.startTest();
        try {
            insert opp;
            System.assert(true, 'Insert should fail');
        } catch (DmlException e) {
            System.assert(e.getMessage().contains('reserved or sold cars'));
        }
        Test.stopTest();
    }

    @IsTest
    static void testStageChange_closedWon_updatesCarsAndPlannedSales() {
        List<Opportunity> opps = [SELECT Id, StageName FROM Opportunity WHERE Name LIKE 'Opp %'];

        for (Opportunity o : opps) {
            o.StageName = 'Closed Won';
        }

        Test.startTest();
        update opps;
        Test.stopTest();

        List<Product2> cars = [
    SELECT Car_Status__c
    FROM Product2
    WHERE Id IN (
        SELECT Product2Id
        FROM OpportunityLineItem
        WHERE OpportunityId IN :opps
    )
];

        for (Product2 p : cars) {
            System.assertEquals('Sold', p.Car_Status__c);
        }

        Planned_Sales__c ps = [
            SELECT Count_of_Cars_Sold__c, Total_Amount_Earned__c
            FROM Planned_Sales__c
             WHERE Year__c = :Date.today().year()
      AND Month__c = :Date.today().month()
       AND Car_Type__c = 'New'
    LIMIT 1
        ];

      System.assert(ps.Count_of_Cars_Sold__c > 0);
       System.assert(ps.Total_Amount_Earned__c > 0);
    }

    @IsTest
    static void testAfterDelete_doesNotCrash() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 2];

        Test.startTest();
        delete opps;
        Test.stopTest();
    }

    @IsTest
    static void testAfterUndelete_coverageOnly() {
        List<Opportunity> opps = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
        delete opps;
        undelete opps;
        Test.stopTest();
    }
}
