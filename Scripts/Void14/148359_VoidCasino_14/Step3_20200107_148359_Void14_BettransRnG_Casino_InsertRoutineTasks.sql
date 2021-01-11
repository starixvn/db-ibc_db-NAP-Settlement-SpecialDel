/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date 20210107
	Task: Support to void tickets in bettransRnG14 - [Redmine: 148359]
	DB: DBTXN/bodb02
	
*/ 
USE bodb02
GO
-- Prepare data for update summary tickets
DECLARE @AffectedList	VARCHAR(MAX)
SET @AffectedList = CAST((
	SELECT custId AS '@c'
			,winlostDate AS '@w'
FROM  bettransRnG14 br WITH (NOLOCK)		
WHERE custid IN (47485411,47502469)		
	AND transid IN (102754618756,102755264965,102758269772,102758315358,102758324906)		
GROUP BY custid, winlostdate	
	FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))

-- INSERT Routine tasks in queue tables for sum_winloss, statement ...: All will be handled by sql job afterwards.
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList
