/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_Bettrans] 
	@BetTickets			TVP_Settlement_BetTicket READONLY
	,@Action			VARCHAR(20)		= NULL
	,@CWLBettype		SMALLINT 		= 0
	,@BalanceUpd		VARCHAR(MAX)	= NULL 	OUTPUT
	,@matchid			INT				= 0
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
	,@TicketType		VARCHAR(1)		= 's'
	,@transMPO			VARCHAR(MAX)	= NULL 	
AS
/*
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170821@Bobby: 81907-  correct recommend info to do settlement on replicas DB05XXX
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221109@Louisa: log more info [Redmine:#178694]
		- 20230905@Aries: Set Max Payout for Non-sports Products [Redmine:#193259]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON 
	
	DECLARE @strBetTicket		VARCHAR(MAX),
			@handle 			INT

	DECLARE @tmpTransMPO TABLE (TransID BIGINT,actualPO MONEY)

	--Tracing company winlimit control
	CREATE TABLE #BalanceCWLBefore (custid INT, winlostdate SMALLDATETIME, gametypeid SMALLINT, balance MONEY, winlost MONEY)
	CREATE TABLE #BalanceCWLAfter (custid INT, winlostdate SMALLDATETIME, gametypeid SMALLINT, balance MONEY, winlost MONEY)
	
	--RESET output
	SELECT  @ErrCode	= 0
		, @ErrMsg		= ''
		, @BalanceUpd 	= NULL
	
	--BEGIN: CAPTURE value BALANCE before calculating
	INSERT INTO #BalanceCWLBefore (
		custid
		, winlostdate 
		, gametypeid
		, balance 
		, winlost 
	)
	SELECT t.custid
		,CASE WHEN t.bettype = 2799  THEN t.winlostdate ELSE b.winlostdate END AS winlostdate
		,t.bettype AS gametypeid
		,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		,SUM(CASE
				WHEN b.ruben = 1 THEN b.winlost - b.actual_stake 
				ELSE 0 
			END) AS winlost
	FROM dbo.bettrans b WITH(ROWLOCK)
		INNER JOIN @BetTickets AS t 
			ON  b.matchid 	= t.matchid
			AND b.custid 	= t.custid
			AND b.bettype 	= t.bettype
			AND b.transid 	= t.transid
	
	GROUP BY t.custid
		, CASE WHEN t.bettype = 2799  THEN t.winlostdate ELSE b.winlostdate END
		, t.bettype
	
	-------------------------------------------------------------
	---        TODO UPDATE bettrans                           ---
	---------------------------VVVV------------------------------
	
	BEGIN TRY
		EXEC sp_xml_preparedocument @handle OUTPUT, @transMPO
		INSERT INTO @tmpTransMPO(TransID, actualPO)
		SELECT t, apo
		FROM OPENXML(@handle,'root/r',1) WITH(t BIGINT, apo	MONEY) tbl
		EXEC sp_xml_removedocument @handle

		
		SELECT @strBetTicket = CONVERT(VARCHAR(MAX)
									,(SELECT b.recommend 						AS '@rec'
											,b.matchid 							AS '@mi'
											,b.custid  							AS '@ci'
											,b.bettype 							AS '@bt'
											,b.transid 							AS '@ti'
											,b.winlost 							AS '@wl'
											,b.awinlost 						AS '@awl'
											,b.mwinlost 						AS '@mwl'				
											,b.swinlost 						AS '@swl'
											,b.playercomm 						AS '@pcomm'
											,b.comm 							AS '@comm'
											,b.acomm 							AS '@acomm'
											,b.scomm 							AS '@scomm'	
											,b.statusid 						AS '@st'	
											,b.modds 							AS '@mo'
											,b.winlostdate						AS '@wd'
											,IIF(mpo.transid IS NOT NULL,1,0)	AS '@iMPO'		
											,mpo.actualPO						AS '@apo'	
										FROM @BetTickets AS b
											LEFT JOIN @tmpTransMPO AS mpo ON b.transid = mpo.transid
										FOR XML PATH('r'), ROOT('root'), TYPE
									) 
								)
								
		EXEC dbo.Bet_ExecRep_BettransUpd @BetTickets = @strBetTicket, @matchid = @matchid, @Action = @Action, @TicketType = @TicketType
			
	END TRY
	BEGIN CATCH
	
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
			
	END CATCH
	
	--BEGIN: CAPTURE value BALANCE after calculating
	INSERT INTO #BalanceCWLAfter(
		custid
		, winlostdate 
		, gametypeid
		, balance 
		, winlost 
	)
	SELECT t.custid
		,CASE WHEN t.bettype = 2799  THEN t.winlostdate ELSE b.winlostdate END AS winlostdate
		,t.bettype AS gametypeid
		,SUM(b.winlost - b.actual_stake + b.playercomm) AS balance
		,SUM(CASE
				WHEN b.ruben = 1 THEN b.winlost - b.actual_stake 
				ELSE 0 
			END) AS winlost
	FROM dbo.bettrans b WITH(ROWLOCK)
		INNER JOIN @BetTickets AS t 
			ON  b.matchid 	= t.matchid
			AND b.custid 	= t.custid
			AND b.bettype 	= t.bettype
			AND b.transid 	= t.transid
	
	GROUP BY t.custid
		, CASE WHEN t.bettype = 2799  THEN t.winlostdate ELSE b.winlostdate END
		, t.bettype
	
	IF(@@ROWCOUNT > 0)
	BEGIN		
		-- OUTPUT updated balance custid
		SELECT @BalanceUpd = CAST((
				SELECT a.custid		AS '@c'
					,SUM(b.balance) AS '@b'
					,SUM(a.balance) AS '@a'
				FROM #BalanceCWLBefore b
					INNER JOIN #BalanceCWLAfter a 
					ON	a.custid 			= b.custid
						AND a.gametypeid 	= b.gametypeid
						AND a.winlostdate 	= b.winlostdate
						
				GROUP BY a.custid
				HAVING SUM(b.balance) <> SUM(a.balance)
				FOR XML PATH('r'), TYPE
			) AS VARCHAR(MAX))

		IF(@CWLBettype > 0)--BEGIN: integrating with company winlimit
		BEGIN
			--CAPTURE increase
			INSERT INTO dbo.BalancePendingCreditGame (
				custid
				,winlostdate
				,bettype
				,GameTypeID
				,balance
			)
			SELECT a.custid
				,a.winlostdate
				,@CWLBettype AS bettype
				,a.gametypeid
				,(a.winlost - b.winlost) AS Balance
			FROM #BalanceCWLBefore b
				INNER JOIN #BalanceCWLAfter a 
				ON	a.custid 			= b.custid
					AND a.winlostdate 	= b.winlostdate
					AND a.gametypeid 	= b.gametypeid
			WHERE a.winlost > b.winlost
			
			--CAPTURE decrease
			INSERT INTO dbo.BalancePendingDebitGame (
				custid
				,winlostdate
				,bettype
				,GameTypeID
				,balance
			)
			SELECT a.custid
				,a.winlostdate
				,@CWLBettype AS bettype
				,a.gametypeid
				,ABS(a.winlost - b.winlost) AS Balance
			FROM #BalanceCWLBefore b
				INNER JOIN #BalanceCWLAfter a 
				ON	a.custid 			= b.custid
					AND a.winlostdate 	= b.winlostdate
					AND a.gametypeid 	= b.gametypeid
			WHERE a.winlost < b.winlost
			
		END --END: integrating with company winlimit
	END	
	
END
GO
