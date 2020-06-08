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

    Param's Explanation:
        
*/
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @xmlParlayTicket 	XML
			,@IsUpd_Void BIT = 0
		
	CREATE TABLE #parlayTicket (transid BIGINT, refno BIGINT, statusId TINYINT, modds SMALLMONEY)		
	CREATE TABLE #parlayOutput (transid BIGINT, refno BIGINT, statusId TINYINT, statuswinlost TINYINT)		
	
	SET @xmlParlayTicket = CONVERT(XML, @strTransIds)
	
	INSERT INTO #parlayTicket (transid, refno, statusId, modds)
	SELECT T.C.value('./@t', 'BIGINT') 			AS transid
			,T.C.value('./@r', 'BIGINT') 		AS refno
			,T.C.value('./@s', 'TINYINT') 		AS statusId
			,T.C.value('./@m', 'SMALLMONEY') 	AS modds
	FROM @xmlParlayTicket.nodes('/b') AS T(C)
	OPTION (OPTIMIZE FOR (@xmlParlayTicket = NULL ))
	
	IF(@@ROWCOUNT = 0) RETURN
	
	--CALCULATE PROCESS
	IF (@action IN ('ABANDONED', 'REFUND'))
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET 
			@IsUpd_Void = CASE WHEN bm.statusID = 102 THEN 0 ELSE 1 END
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
		INTO #parlayOutput(transid, refno, statusID, statuswinlost)
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
	
	IF (@action IN ('CAL'))
	BEGIN
		--UPDATE bettransm
		UPDATE bm
		SET 
			@IsUpd_Void = CASE WHEN bm.statusID = 102 THEN 0 ELSE 1 END
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
		INTO #parlayOutput(transid, refno, statusID, statuswinlost)
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
	
	IF (@action IN ('UNDO'))
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
				,INSERTED.statuswinlost
		INTO #parlayOutput(transid, refno, statusID, statuswinlost)
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
	
	DROP TABLE #parlayTicket;
	DROP TABLE #parlayOutput
	RETURN;
END

GO