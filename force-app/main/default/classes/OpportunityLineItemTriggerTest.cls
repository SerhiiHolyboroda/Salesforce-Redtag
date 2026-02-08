@IsTest
public class OpportunityLineItemTriggerTest {

    @TestSetup
    static void setup() {
        Account acc = TestDataFactory.createAccount();
        List<Product2> cars = TestDataFactory.createCars(3, 'Available', 'Sale');
        List<PricebookEntry> pbes = TestDataFactory.createPBEs(cars);
        List<Opportunity> opps = TestDataFactory.createOpportunities(acc, 3, 'Prospecting');

        TestDataFactory.createOLIs(opps, pbes, 1);
    }

    @IsTest
    static void testQuantityOne_positive() {
        List<OpportunityLineItem> olis = [SELECT Id FROM OpportunityLineItem];
        Test.startTest();
        update olis;
        Test.stopTest();
    }

    @IsTest
    static void testQuantityOne_negative() {
        List<OpportunityLineItem> olis = [SELECT Id, Quantity FROM OpportunityLineItem];

        for (OpportunityLineItem oli : olis) {
            oli.Quantity = 2;
        }

        Test.startTest();
        try {
            update olis;
            System.assert(false, 'Expected validation error');
        } catch (DmlException e) {
            System.assert(
                e.getMessage().contains('Quantity must be 1'),
                'Expected quantity validation error'
            );
        }
        Test.stopTest();
    }
}