/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Parlay_Calculate_3]
	@matchid 		INT
	,@matchdate		SMALLDATETIME
    ,@Action		VARCHAR(10)
	,@strTransIds 	VARCHAR(MAX) = NULL
AS
/*    
	Creator: 20161205@Bobby
    Task: #61352 - Apply settle determined for parlay bet types
    DB: DBTXN.bodb02
	Original:

    Revisions:        
		- 20170609@Kathy: Early Settlement - BAIO [Redmine:#77835]
		- 20170719@Kathy: Correct statuswinlost of refund [Redmine:#77835]
		- 20180801@Vicky: Incorporate eSports 2.0 [Redmine #95874]
		- 20190715@Helen: Recover/Void tickets in Bet 14 - Update statuswinlost for VOID Tickets [Redmine:115377]
		- 20200511@Kathy: Remove tennis code [Redmine:#129316]
		- 20210514@Kathy: settle parlay ticket [Redmine:#154737]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]

    Param's Explanation:
        
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @xmlParlayTicket 	XML
			,@IsUpd_Void BIT = 0
			,@transinfo XML
			,@IsSiteDB	BIT

	CREATE TABLE #parlayTicket (transid BIGINT, refno BIGINT, statusId TINYINT, modds SMALLMONEY, IsMarked BIT DEFAULT(0))		
	CREATE TABLE #parlayOutput (transid BIGINT, refno BIGINT, statusId TINYINT, statuswinlost TINYINT, winlostdate SMALLDATETIME, status VARCHAR(10), ruben TINYINT)		
	
	SET @xmlParlayTicket = CONVERT(XML, @strTransIds)
	
	INSERT INTO #parlayTicket (transid, refno, statusId, modds, IsMarked)
	SELECT T.C.value('./@t', 'BIGINT') 			AS transid
			,T.C.value('./@r', 'BIGINT') 		AS refno
			,T.C.value('./@s', 'TINYINT') 		AS statusId
			,T.C.value('./@m', 'SMALLMONEY') 	AS modds
			,T.C.value('./@im', 'BIT') 	AS IsMarked
	FROM @xmlParlayTicket.nodes('/b') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlParlayTicket = NULL ))
	
	IF(@@ROWCOUNT = 0) RETURN

	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1
	
	--CALCULATE PROCESS
	IF @action = 'ABANDONED'  OR @Action LIKE 'REFUND%'
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET 
			@IsUpd_Void = CASE WHEN bm.statusID = 102 OR t.IsMarked = 1 THEN 0 ELSE 1 END
			,winlostdate = CASE 
								WHEN @IsUpd_Void = 0 THEN winlostdate 
								ELSE @matchdate
							END 
			,[status] 	= CASE 
								WHEN @IsUpd_Void = 0 THEN bm.[status] 
								ELSE CASE 
											WHEN t.modds = 0 THEN 'Refund'
											WHEN t.modds < 0 THEN 'LOSE'
											WHEN t.modds > 0 THEN 'WON'
											ELSE bm.[status]
									END
							END
			,statusID = CASE 
							WHEN @IsUpd_Void = 0 THEN bm.statusID 
							ELSE CASE 
									WHEN t.modds = 0 THEN 103 
									WHEN t.modds < 0 THEN 113
									WHEN t.modds > 0 THEN 112
									ELSE bm.statusID
								END
							END
			
			,statuswinlost = CASE 
								WHEN t.modds > 0.25 THEN 2 -- WON
								WHEN t.modds = 0.25 THEN 1 -- Half WON
								WHEN t.modds = - 0.25 THEN 3 -- Half LOSE
								WHEN t.modds < - 0.25 THEN 4 -- LOSE
								ELSE 6 -- REFUND
							END
			,ruben = 1
		OUTPUT INSERTED.transid
				,INSERTED.refno
				,INSERTED.statusID
				,INSERTED.statuswinlost
				,inserted.winlostdate
				,inserted.status
				,inserted.ruben
		INTO #parlayOutput(transid, refno, statusID, statuswinlost , winlostdate, status, ruben)
		FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayTicket t
			ON bm.refno = t.refno AND bm.transid = t.transid

		--UPDATE BetParlayDetail
		UPDATE pd 
		SET winlostdate 	= @matchdate
			,statusid 		= r.statusId
			,statuswinlost 	= r.statuswinlost
		FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayOutput r
			ON pd.transid 	= r.transid
			AND pd.RefNo 	= r.refno
		WHERE r.statusid NOT IN (102)
			
	END

	IF @action LIKE 'CAL%'
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET 
			@IsUpd_Void = CASE WHEN bm.statusID = 102 OR t.IsMarked = 1 THEN 0 ELSE 1 END
			,ruben = CASE 
						WHEN @IsUpd_Void = 0 THEN ruben 
						ELSE CASE 
								WHEN t.modds IS NULL THEN 0
								ELSE 1
							END
					END

			,winlostdate = CASE 
								WHEN @IsUpd_Void = 0 THEN bm.winlostdate 
								ELSE @matchdate
							END

			,[status] = CASE 
							WHEN @IsUpd_Void = 0 THEN [status] 
							ELSE CASE 
									WHEN t.modds IS NULL THEN N'running'
									WHEN t.modds = 0  THEN N'DRAW'
									WHEN t.modds < 0 THEN N'LOSE'
									WHEN t.modds > 0 THEN N'WON'
								END
							END
							
			,statusID = CASE 
								WHEN @IsUpd_Void = 0 THEN bm.statusID 
								ELSE CASE 
										WHEN t.modds IS NULL THEN 0
										WHEN t.modds = 0 THEN 111
										WHEN t.modds < 0 THEN 113
										WHEN t.modds > 0 THEN 112
									END
							END
			,statuswinlost = CASE 
								WHEN t.modds > 0.25 THEN 2 -- WON
								WHEN t.modds = 0.25 THEN 1 -- Half WON
								WHEN t.modds = - 0.25 THEN 3 -- Half LOSE
								WHEN t.modds < - 0.25 THEN 4 -- LOSE
								ELSE 0 -- DRAW
							END
		OUTPUT INSERTED.transid
				,INSERTED.refno
				,INSERTED.statusID
				,INSERTED.statuswinlost
				,inserted.winlostdate
				,inserted.status
				,inserted.ruben
		INTO #parlayOutput(transid, refno, statusID, statuswinlost, winlostdate, status, ruben)
		FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayTicket t
			ON bm.refno = t.refno AND bm.transid = t.transid
	
		--UPDATE BetParlayDetail
		UPDATE pd 
		SET winlostdate 	= @matchdate
			,statusid 		= r.statusId
			,statuswinlost 	= r.statuswinlost
		FROM dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayOutput r
			ON pd.transid 	= r.transid
			AND pd.RefNo 	= r.refno
		WHERE r.statusId NOT IN (102)	
	END
	
	IF @action LIKE 'UNDO%'
	BEGIN
		 --update bettransm
	    UPDATE bm
	    SET 
			@IsUpd_Void = CASE WHEN bm.statusID = 102 THEN 0 ELSE 1 END
			,[status]   = CASE WHEN @IsUpd_Void = 0 THEN [status]
								ELSE 'running'
							END
	        ,statuswinlost  = NULL
	        ,ruben          = CASE WHEN @IsUpd_Void = 0 THEN ruben
								ELSE 0
							END
	        ,statusID       = CASE WHEN @IsUpd_Void = 0 THEN bm.statusID
								ELSE 0
							END
	    OUTPUT INSERTED.transid
				,INSERTED.refno
				,INSERTED.statusID
				,Inserted.Statuswinlost
				,inserted.winlostdate
				,inserted.status
				,inserted.ruben
		INTO #parlayOutput(transid, refno, statusID, statuswinlost, winlostdate, status, ruben)
		FROM dbo.bettransm bm WITH(ROWLOCK, UPDLOCK)
			INNER JOIN #parlayTicket t
			ON bm.refno = t.refno AND bm.transid = t.transid        
	          
	    
	    --update BetParlayDetail
	    UPDATE pd
	    SET statuswinlost   = 0
	        ,statusID       = 0
	    FROM dbo.BetParlayDetail pd WITH (ROWLOCK, UPDLOCK)
	        INNER JOIN #parlayOutput r ON pd.transid = r.transid AND pd.RefNo = r.refno
	    WHERE r.statusid NOT IN (102) 
	END
	
	IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM #parlayOutput)
	BEGIN
		SET @transInfo = (
			SELECT	transId AS '@t'							
					,CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END AS '@statuswl'
					,Status AS '@s' 
					,StatusID AS '@sid' 
					,winlostdate AS '@wld'
					,ruben AS '@r' -- ruben	
			FROM	#parlayOutput
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		-- bettransm
		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
		SELECT  'Settlement'
				, CASE  WHEN  @action = 'ABANDONED'  OR @Action LIKE 'REFUND%' THEN 'RefundSubParlay'
						WHEN @Action LIKE 'CAL%' THEN 'CalculateSubParlay'
						WHEN  @action LIKE 'UNDO%' THEN  'UndoSubParlay'
						END
				, 'bettransm'
				, @MatchId
				, @transInfo
				, CASE 
					WHEN @action = 'ABANDONED'  OR @Action LIKE 'REFUND%' THEN 'REFUND'
					WHEN @Action LIKE 'CAL%' THEN 'CAL'
					WHEN @Action LIKE 'UNDO%' THEN 'UNDO'
				END
				, 'p'
		WHERE @transInfo IS NOT NULL
			
		SET @transInfo = (
			SELECT	transId AS '@t'							
					,CASE WHEN @Action LIKE 'UNDO%' THEN '0' ELSE CASE WHEN statuswinlost IS NULL THEN '' ELSE CAST(statuswinlost AS VARCHAR(1)) END END AS '@statuswl'
					,statusId AS '@sid' 
					,winlostdate AS '@wld'
			FROM	#parlayOutput
			FOR XML PATH('r'),ROOT('root'), TYPE
		)

		INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, SettlementAction, TicketType)
		SELECT 'Settlement'
				, CASE  
					WHEN @action = 'ABANDONED'  OR @Action LIKE 'REFUND%' THEN 'RefundSubParlay'
					WHEN @Action LIKE 'CAL%' THEN 'CalculateSubParlay'
					WHEN  @action LIKE 'UNDO%' THEN  'UndoSubParlay'
				END
				, 'BetParlayDetail'
				, @MatchId
				, @transInfo
				, CASE 
					WHEN @action = 'ABANDONED'  OR @Action LIKE 'REFUND%' THEN 'REFUND'
					WHEN @Action LIKE 'CAL%' THEN 'CAL'
					WHEN @Action LIKE 'UNDO%' THEN 'UNDO'
				END
				, 'p'
		WHERE @transInfo IS NOT NULL

	END

	DROP TABLE #parlayTicket;
	DROP TABLE #parlayOutput
	RETURN;
END

GO