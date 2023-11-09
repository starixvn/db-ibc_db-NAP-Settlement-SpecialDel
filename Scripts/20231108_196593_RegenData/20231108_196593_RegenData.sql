/*<info serverAlias="DBSIG-bodb02" executers="" isFunction="0"></info>*/
/*	
	Created: 20230727@Aries
	Task: Regen data for table sum after data patch in bettrans14 - [Redmine: 196593]
	DB: DBSIG/bodb02
*/ 
USE bodb02
GO
---RUN ON SITEDB1 ONLY

DECLARE @AffectedList	VARCHAR(MAX)
SET @AffectedList = CAST((
	SELECT 101647305 AS '@c' -- custid
	     ,'2023-11-03 00:00:00' AS '@w' -- winlostdate

	FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))

EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert @AffectedList = @AffectedList, @IsSiteDB = 1 