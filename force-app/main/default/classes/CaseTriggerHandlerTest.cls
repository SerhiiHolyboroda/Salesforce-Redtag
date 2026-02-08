@IsTest
public class CaseTriggerHandlerTest {

    /* ===============================
       Test Setup
    =============================== */
    @TestSetup
    static void setup() {

        // Create Queue
        Group serviceQueue = new Group(
            Name = 'Service Cases',
            Type = 'Queue'
        );
        insert serviceQueue;

        // Link queue to Case object
        QueueSobject qs = new QueueSobject(
            QueueId = serviceQueue.Id,
            SobjectType = 'Case'
        );
        insert qs;

        // Create Car (Product2)
        Product2 car = new Product2(
            Name = 'Test Car',
            IsActive = true,
            VIN_Number__c = 'VIN-12345'
        );
        insert car;
    }

    /* ===============================
       Main Happy Path Test
    =============================== */
    @IsTest
    static void testWebCaseCreatesCarServiceAndEmail() {

        Test.startTest();

        Case c = new Case(
            SuppliedName = 'John Doe',
            SuppliedEmail = 'john@test.com',
            SuppliedPhone = '123456789',
            Subject = 'Car service request',
            Description = 'Need oil change',
            Car_Vin_Code__c = 'VIN-12345'
        );
        insert c;

        Test.stopTest();

        // Reload Case
        Case insertedCase = [
            SELECT Origin, OwnerId, Car_Service__c
            FROM Case
            WHERE Id = :c.Id
        ];

        // Assert Origin
        System.assertEquals(
            'Web Car Service',
            insertedCase.Origin,
            'Origin should be set by trigger'
        );

        // Assert Owner is Queue
        Group queue = [
            SELECT Id
            FROM Group
            WHERE Name = 'Service Cases'
            LIMIT 1
        ];
        System.assertEquals(
            queue.Id,
            insertedCase.OwnerId,
            'Case should be assigned to Service Cases queue'
        );

        // Assert Car Service created
        Car_Service__c cs = [
            SELECT Id, Car__c, Case__c
            FROM Car_Service__c
            WHERE Case__c = :c.Id
            LIMIT 1
        ];

        System.assertEquals(
            c.Id,
            cs.Case__c,
            'Car Service must be linked to Case'
        );

        System.assertNotEquals(
            null,
            cs.Car__c,
            'Car Service must be linked to Car'
        );

        // Assert email was sent
        System.assertEquals(
            1,
            Limits.getEmailInvocations(),
            'Confirmation email should be sent'
        );
    }

    /* ===============================
       No VIN → No Car Service
    =============================== */
    @IsTest
    static void testCaseWithoutVinDoesNotCreateCarService() {

        Test.startTest();

        Case c = new Case(
            SuppliedName = 'Jane Doe',
            SuppliedEmail = 'jane@test.com',
            SuppliedPhone = '999999',
            Subject = 'General request'
        );
        insert c;

        Test.stopTest();

        Integer countCS = [
            SELECT COUNT()
            FROM Car_Service__c
            WHERE Case__c = :c.Id
        ];

        System.assertEquals(
            0,
            countCS,
            'No Car Service should be created when VIN is missing'
        );
    }

    /* ===============================
       No Email → No Email Sent
    =============================== */
    @IsTest
    static void testCaseWithoutEmailDoesNotSendEmail() {

        Test.startTest();

        Case c = new Case(
            SuppliedName = 'No Email User',
            SuppliedPhone = '555555',
            Subject = 'No email case',
            Car_Vin_Code__c = 'VIN-12345'
        );
        insert c;

        Test.stopTest();

        System.assertEquals(
            0,
            Limits.getEmailInvocations(),
            'Email should not be sent when SuppliedEmail is blank'
        );
    }
}