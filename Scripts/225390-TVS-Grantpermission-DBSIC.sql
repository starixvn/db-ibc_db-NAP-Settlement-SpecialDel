/*<info serverAlias="DBSIC-CustDB" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20250708@July
    DB: DBSIC-CustDB
    
    Revisions:            
		- 20250708@July:  Integrate - Agency Cash Service - Negative Balance [Redmine:#225390]

*/
USE CustDB
GRANT SELECT ON dbo.CustProductStatus TO wsv_nap; 