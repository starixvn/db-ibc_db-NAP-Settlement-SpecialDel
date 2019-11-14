/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_SubParlay14] (@transIds VARCHAR(MAX))
AS
/*
	Created by: 20190715@Helen
	Task: Settlement  
	DB: DBTRANS/BODB02
	
	Revisions:
		- 20190715@Helen: Recover/Void tickets in Bet 14 - [Redmine:115377]
		
	Param's Explanation:  
		   
		@transIds = '104730774034,104729373985'
					
*/
BEGIN
	
	SET NOCOUNT ON

	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN

	END
	-----------------------CHECK SERVER-----------------------------------------
	DECLARE @xml XML
		   ,@transids_29 VARCHAR(MAX) = ''
		   ,@refnos_29	VARCHAR(MAX) = ''
		   ,@MatchDate	DATETIME
		   ,@matchid INT
		   
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)
	DECLARE @tbl_Refno AS TABLE(refno BIGINT)
	DECLARE @tbl_MainTickets AS TABLE (transid BIGINT,refno BIGINT)
	
		
	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	SET @matchid = (SELECT TOP 1 b14.matchid 
					FROM bettransm14 b14 WITH (NOLOCK)
						INNER JOIN @tbl_transIDs t ON b14.transid = t.transid
					)
	
	SELECT  @MatchDate = eventdate
	FROM	dbo.match14 WITH(NOLOCK)
	WHERE	matchid = @matchid
		
	INSERT INTO @tbl_Refno (refno)
	SELECT b14.refno
	FROM @tbl_transIDs t 
		INNER JOIN bettransm14 b14 WITH (NOLOCK) ON t.transid = b14.transid
	GROUP BY b14.refno
	
	INSERT INTO @tbl_MainTickets (transid, refno)
	SELECT main.transid, t.refno
	FROM @tbl_Refno t
		CROSS APPLY (SELECT transid
					 FROM bettrans b1 WITH (NOLOCK)
					 WHERE b1.refno = t.refno AND b1.matchid = 29 AND b1.statusID NOT IN (101, 102)
					 UNION ALL
					 SELECT transid
					 FROM bettrans14 b2 WITH (NOLOCK)
					 WHERE b2.refno = t.refno AND b2.matchid = 29 AND b2.statusID NOT IN (101, 102)
					 ) AS main
					 
	-- Step 1: Update sub parlay first - bettransm14 processing
	UPDATE	bm WITH (ROWLOCK, UPDLOCK)
		SET 
			ruben = 1
			,[status] = CASE 
							WHEN statuswinlost = 0  THEN N'DRAW'
							WHEN statuswinlost = 6 THEN N'Refund'
							WHEN statuswinlost IN (3,4) THEN N'LOSE'
							WHEN statuswinlost IN (1,2) THEN N'WON'
						END
					
					
			,statusID = CASE 
							WHEN statuswinlost = 0 THEN 111
							WHEN statuswinlost = 6 THEN 103 
							WHEN statuswinlost IN (3,4) THEN 113
							WHEN statuswinlost IN (1,2) THEN 112
						END
	FROM	dbo.bettransm14 bm 
		INNER JOIN @tbl_transIDs t ON	bm.transid = t.transid
	-- Step 2: BetParlayDetail					
	UPDATE	pd 
		SET statusID = b14.statusID
			,statuswinlost = b14.statuswinlost
	FROM    dbo.BetParlayDetail pd WITH(ROWLOCK, UPDLOCK)
		INNER JOIN @tbl_transIDs t ON  pd.transid = t.transid
		INNER JOIN bettransm14 b14 ON b14.transid = t.transid
	
	-- Step 3: Resettle main ticket
	-- Step 3.1: Generate sub-ticket for combination (PreCal29)
	
	SELECT @transids_29 = @transids_29 + CONVERT(VARCHAR(20), transid) + ','
			 , @refnos_29 = @refnos_29 + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid) + ','
	FROM @tbl_MainTickets
	
	EXEC dbo.NAP_Admin_Calculate_MP_Bet14_PreCal_29 @matchdate = @MatchDate
           ,@strXML	= @transids_29
            			
	-- Step 3.2: Re-settle for main ticket
	EXEC dbo.NAP_Admin_Calculate_MP_Bet14_29  
            @strXML = @refnos_29 -- main transid + refno: refno|transid,refno|transid...
	
END
GO