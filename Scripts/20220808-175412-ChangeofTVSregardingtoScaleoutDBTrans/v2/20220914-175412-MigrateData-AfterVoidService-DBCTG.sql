/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*
    Created: 20220808@Max
	Task: Migrate old data Ticketvoiding_VoidBetAutomation_Service - [Redmine:#175412]  
	DB: DBCTG-bodb02
*/

USE bodb02
GO

DECLARE @batch INT = 3000;

--Migrate Cancel, MixParlay(99) queue to compepleted for consistency with new web service
WHILE (1 = 1)
BEGIN
	UPDATE TOP (@batch) q	
		SET q.StatusId = CASE WHEN q.statusID = 12 THEN 2 
							WHEN q.statusID = 13 THEN 2
						END
	FROM dbo.Ticketvoiding_VoidBetAutomation_Service q WITH(ROWLOCK, UPDLOCK)
	WHERE q.StatusId IN (12, 13)

	IF @@ROWCOUNT = 0 BREAK

	WAITFOR DELAY '00:00:00.100'
END





