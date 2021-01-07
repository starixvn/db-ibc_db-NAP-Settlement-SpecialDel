/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
/*	
	Created by: Helen
	Date 20210107
	Task: Support to void tickets in bettransRnG14 - [Redmine: 148359]
	DB: DBTXN/bodb02
	
	SELECT distinct refno
	FROM  bettransRnG14 br WITH (NOLOCK)		
	WHERE custid IN (47485411,47502469)		
		AND transid IN (102754618756,102755264965,102758269772,102758315358,102758324906)		
	
	
	SELECT b.custid, b.winlostdate
				,b.stake 
				,b.actual_stake 
				,b.Winlost 
				,b.aWinlost 
				,b.mWinlost 
				,b.sWinlost 
				,b.playerComm 
				,b.Comm 
				,b.aComm 
				,b.sComm 
	FROM  bettrans14 b with (nolock) 
	WHERE transid in (110783316475,110791291468)
	GROUP BY b.custid, b.winlostdate 
	
	custid		winlostdate	stake		actual_stake		Winlost		aWinlost		mWinlost		sWinlost	playerComm	Comm	aComm	sComm
	47485411	2021-01-01 00:00:00		300.00				300.00		720.00			-378.00	0.00	0.00		0.00		0.00	0.00	0.00
	47502469	2021-01-02 00:00:00		4510.00	4510.00		10040.00	-4977.00		0.00			0.00		0.00		0.00	0.00	0.00
	
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
				,0.00 AS '@st'
				,0.00 AS '@ast'
				,-340.00 AS '@w_dif'
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
				,0.00 AS '@st'
				,0.00 AS '@ast'
				,-4690.00 AS '@w_dif'
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

