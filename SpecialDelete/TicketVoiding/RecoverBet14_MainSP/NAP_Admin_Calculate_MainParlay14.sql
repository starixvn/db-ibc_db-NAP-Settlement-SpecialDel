/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_MainParlay14] (@transIds VARCHAR(MAX))
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
		    ,@RowNumber			INT	= 1
			,@tmp_TransIds		VARCHAR(MAX)
			,@refnos_29			VARCHAR(MAX)
			,@tmp_MatchId		INT
			,@MatchDate			DATETIME
		   
	DECLARE @tbl_transIDs AS TABLE(transid BIGINT)
	
	DECLARE @tblNoResettleTransIds TABLE (transid BIGINT PRIMARY KEY)
	
	CREATE TABLE #tblRecoverBet( transid		BIGINT
								,matchid		INT
								,refno			BIGINT 
								)
	CREATE INDEX IX_RecoverBet ON #tblRecoverBet (refno)
	
	DECLARE @tblMatchIds TABLE ( RowNumber		INT 	IDENTITY (1,1)									
								,matchid		INT
								,eventdate		DATETIME
								,transid		BIGINT
								,refno			BIGINT
								)							
								
		
	SET @XML = N'<root><r>' + REPLACE(@transIds, ',', '</r><r>') + '</r></root>'
	
	INSERT INTO @tbl_transIDs (transid)
	SELECT r.value('.','BIGINT')
	FROM @xml.nodes('//root/r') AS RECORDS(r)
	OPTION (OPTIMIZE FOR (@xml = NULL))
	
	--Transid list is recovered
	INSERT INTO #tblRecoverBet (transid,matchid,refno)
	SELECT	b.transid
			,b.matchid
			,b.refno
	FROM	@tbl_transIDs s 
		INNER LOOP JOIN dbo.bettrans14 b WITH(NOLOCK) ON s.transid = b.transid
	WHERE b.matchid = 29 AND b.bettype = 29 AND b.statusID = 102
	
	INSERT INTO @tblMatchIds (matchid, eventdate, transid, refno)
	SELECT t.matchid, t.eventdate, t.transid, t.refno
	FROM(
		SELECT	ROW_NUMBER() OVER (PARTITION BY b14.transid ORDER BY m14.eventdate DESC) AS RowNumber
				,bm14.matchid, m14.eventdate,  b14.transid, b14.refno
		FROM	dbo.bettransm14 bm14 WITH(NOLOCK) 
			INNER JOIN #tblRecoverBet b14 ON b14.refno = bm14.refno	
			INNER JOIN dbo.match14 m14 WITH (NOLOCK) ON bm14.matchid = m14.matchid		
	) t
	WHERE	t.RowNumber = 1
	
	-- Reset main to running
	UPDATE	b WITH(ROWLOCK, UPDLOCK)
		SET status = 'running'
			,statusID = 0
			,ruben = 0
			,modds = 0
			,winlost = 0
			,awinlost = 0
			,mwinlost = 0
			,swinlost = 0
			,playercomm = 0
			,comm = 0
			,acomm = 0
			,scomm = 0		
			,statuswinlost = NULL
			,creator = b.custid
	FROM dbo.bettrans14 b
		INNER JOIN #tblRecoverBet t ON b.transid = t.transid
			
	WHILE (1 = 1)
	BEGIN
		SELECT	TOP 1 @tmp_MatchId = matchid
		FROM	@tblMatchIds
		WHERE	RowNumber = @RowNumber
	
		IF @@rowcount = 0
			BREAK		
	
		SET @RowNumber = @RowNumber + 1
	
		SELECT  @MatchDate = eventdate
		FROM	dbo.match14 WITH(NOLOCK)
		WHERE	matchid = @tmp_MatchId

		SELECT @tmp_TransIds = ''
		SELECT  @tmp_TransIds = @tmp_TransIds + CONVERT(VARCHAR(20), transid) + ','
		FROM	@tblMatchIds
		WHERE	matchid = @tmp_MatchId

		SELECT @refnos_29 = ''
		SELECT 	@refnos_29 = @refnos_29 + ',' + CONVERT(VARCHAR(20), refno) + '|' + CONVERT(VARCHAR(20), transid)
		FROM	@tblMatchIds
		WHERE	matchid = @tmp_MatchId

		SET @refnos_29 = STUFF(@refnos_29,1,1,'')
	
		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_PreCal_29 
			 @matchdate = @matchdate
			,@strXML = @tmp_TransIds

		EXEC dbo.NAP_Admin_Calculate_MP_Bet14_29
				@strXML	= @refnos_29
				
	END
	
END
GO