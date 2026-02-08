public with sharing class CaseTriggerHandler {

    private static final String WEB_ORIGIN = 'Web Car Service';
    private static final String SERVICE_QUEUE_NAME = 'Test';
  private static final String WEB_ORIGIN_Email = 'Email';
 
    public static void beforeInsert(List<Case> newCases) {

        Id serviceQueueId = getQueueIdByName(SERVICE_QUEUE_NAME);

        for (Case c : newCases) {
            c.Origin = WEB_ORIGIN;

            if (serviceQueueId != null) {
                c.OwnerId = serviceQueueId;
            }
        }

    /* ================= new ================= */



    /* ================= new ================= */
    }

   
    public static void afterInsert(List<Case> newCases) {

        Map<String, Product2> vinToCar = getCarsByVin(newCases);

        List<Car_Service__c> servicesToInsert = new List<Car_Service__c>();
        Map<Id, Id> caseToService = new Map<Id, Id>();

        for (Case c : newCases) {
            if (String.isBlank(c.Car_Vin_Code__c)) continue;

            Product2 matchedCar = vinToCar.get(c.Car_Vin_Code__c);

            if (matchedCar != null) {
                Car_Service__c cs = new Car_Service__c(
                    Car__c = matchedCar.Id,
                    Case__c = c.Id
                );
                servicesToInsert.add(cs);
            }
        }

        if (!servicesToInsert.isEmpty()) {
            insert servicesToInsert;

            for (Car_Service__c cs : servicesToInsert) {
                caseToService.put(cs.Case__c, cs.Id);
            }

            List<Case> casesToUpdate = new List<Case>();
            for (Id caseId : caseToService.keySet()) {
                casesToUpdate.add(new Case(
                    Id = caseId,
                    Car_Service__c = caseToService.get(caseId)
                ));
            }
            update casesToUpdate;
        }

        sendConfirmationEmails(newCases);
    }



    private static Id getQueueIdByName(String queueName) {
        Group g = [
            SELECT Id
            FROM Group
            WHERE Name = :queueName
            AND Type = 'Queue'
            LIMIT 1
        ];
        return g != null ? g.Id : null;
    }

    private static Map<String, Product2> getCarsByVin(List<Case> cases) {

        Set<String> vins = new Set<String>();
        for (Case c : cases) {
            if (!String.isBlank(c.Car_Vin_Code__c)) {
                vins.add(c.Car_Vin_Code__c);
            }
        }

        if (vins.isEmpty()) return new Map<String, Product2>();

        Map<String, Product2> result = new Map<String, Product2>();
        for (Product2 car : [
            SELECT Id, VIN_Number__c
            FROM Product2
            WHERE VIN_Number__c IN :vins
        ]) {
            result.put(car.VIN_Number__c, car);
        }

        return result;
    }

    public  static void sendConfirmationEmails(List<Case> cases) {

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Case c : cases) {
            if (String.isBlank(c.SuppliedEmail)) continue;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { c.SuppliedEmail });
            mail.setSubject('We received your car service request');
            mail.setPlainTextBody(
                'Hello ' + c.SuppliedName + ',\n\n' +
                'We have successfully received your car service request.\n' +
                'Our service team will contact you shortly.\n\n' +
                'Thank you!'
            );
            emails.add(mail);
        }

        if (!emails.isEmpty()) {
            System.Debug(emails);
            Messaging.sendEmail(emails);
        }
    }
}