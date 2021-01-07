/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date 20210107
	Task: Support to void tickets in bettransRnG14 - [Redmine: 148359]
	DB: DBTXN/bodb02
	
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
	
*/ 
USE bodb02
GO
-- Prepare data for update summary tickets
DECLARE @AffectedList	VARCHAR(MAX)
SET @AffectedList = CAST((
	SELECT * 
	FROM 
		(SELECT 47485411 AS '@c'
				,'2021-01-01' AS '@w'
				,-60.00 AS '@st'
				,-60.00 AS '@ast'
				,-400.00 AS '@w_dif'
				,306.00 AS '@aw_dif'
				,0.00 AS '@mw_dif'
				,0.00 AS '@sw_dif'
				,0.00 AS '@pc_dif'
				,0.00 AS '@c_dif'
				,0.00 AS '@ac_dif'
				,0.00 AS '@sc_dif'
		UNION ALL
		SELECT 47502469 AS '@c'
				,'2021-01-02' AS '@w'
				,-810.00 AS '@st'
				,-810.00 AS '@ast'
				,-5500.00 AS '@w_dif'
				,4221.00 AS '@aw_dif'
				,0.00 AS '@mw_dif'
				,0.00 AS '@sw_dif'
				,0.00 AS '@pc_dif'
				,0.00 AS '@c_dif'
				,0.00 AS '@ac_dif'
				,0.00 AS '@sc_dif'
				) AS T
	FOR XML PATH('r'), ROOT('root'), TYPE
) AS VARCHAR(MAX))

--SELECT @AffectedList

-- update summary tickets - bettype 19999
EXEC dbo.TicketVoiding_Admin_Bet14_19999 
	@AffectedList = @AffectedList

