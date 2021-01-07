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
			,-SUM(stake) AS '@st'
			,-SUM(actual_stake) AS '@ast'
			,-SUM(Winlost) AS '@w_dif'
			,-SUM(aWinlost) AS '@aw_dif'
			,-SUM(mWinlost) AS '@mw_dif'
			,-SUM(sWinlost) AS '@sw_dif'
			,-SUM(playerComm) AS '@pc_dif'
			,-SUM(Comm) AS '@c_dif'
			,-SUM(aComm) AS '@ac_dif'
			,-SUM(sComm) AS '@sc_dif'
FROM  bettransRnG14 br WITH (NOLOCK)		
WHERE custid IN (47485411,47502469)		
	AND transid IN (102754618756,102755264965,102758269772,102758315358,102758324906)		
GROUP BY custid, winlostdate	
	FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))

-- update summary tickets - bettype 19999
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList

-- INSERT Routine tasks in queue tables for sum_winloss, statement ...: All will be handled by sql job afterwards.
EXEC dbo.TicketVoiding_Admin_Bet14_RoutineTask_Insert 
	@AffectedList = @AffectedList
