// 1. Query the Opportunity by Id (or any filter)
Opportunity opp = [
    SELECT Id, Name, StageName
    FROM Opportunity
    WHERE Id = '006fj000008vRbZAAU'  // or WHERE Id = '006XXXXXXXXXXXX'
    LIMIT 1
];

// 2. Update the StageName (Status)
opp.StageName = 'Prospecting';  // or any valid StageName
update opp;

// 3. Optional debug
System.debug('Opportunity updated: ' + opp);
