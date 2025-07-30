/*<info serverAlias="DBSIG-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Settlement_1_CashoutTicketSel
	 @ErrCode		INT				= 0	 OUTPUT
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20250214@Louisa
	Task: get list CO ticket [Redmine:#217573]

	Revisions:
		- 20250214@Louisa: get list CO ticket [Redmine:#217573] 
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @MaxValue BIGINT
			,@MatchID INT
			,@leagueId INT
			,@BroadcastSessionId VARCHAR(50)
			,@CurrentLogID BIGINT

	DECLARE @tmp_TicketInfo TABLE (TransId BIGINT, CustID INT , ExtraInfo VARCHAR(1000), bef_sid TINYINT, sid TINYINT, LogId BIGINT )

	SELECT @MaxValue = ( SELECT ISNULL(VValue,0) FROM  dbo.SystemSettings WITH(NOLOCK) WHERE  VName = 'SiteDB_CO_LastLogId')
	
	SELECT TOP 1
		  @MatchID = l.Matchid
		 ,@BroadcastSessionId  = l.BroadcastSessionId
	FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
	WHERE l.LogId > @MaxValue
		AND l.FunctionName= 'CalculateCashout'
		AND l.BroadcastSessionId IS NOT NULL
	ORDER BY l.LogId

	IF @BroadcastSessionId IS NULL
	BEGIN
		SELECT @MatchID AS MatchId, @leagueId AS LeagueId, transid, custid , Extrainfo
				, CASE  WHEN sid IN (111,112,113) THEN 'Undo'
						WHEN sid = 103	THEN 'Void' 
				END [Action]
		FROM  @tmp_TicketInfo

		RETURN
	END

	BEGIN TRY
		INSERT INTO @tmp_TicketInfo (TransId , bef_sid, sid, LogID )
		SELECT t.t AS TransID, t.bef_sid, t.sid, l.LogId	
		FROM dbo.SiteDB_SettlementService_CalculationLog l WITH(NOLOCK)
			 CROSS APPLY OPENJSON(CAST(DECOMPRESS(l.TransInfoJson) AS NVARCHAR(MAX))) 
			 WITH (t  BIGINT,[sid] TINYINT,bef_sid TINYINT) AS t
		WHERE   l.MatchId =  @MatchID
			AND l.BroadcastSessionId = @BroadcastSessionId
	
		SELECT @CurrentLogID =  MAX(LogId)  FROM @tmp_TicketInfo
		
		UPDATE tmp
		SET CustID = b.custid
			,ExtraInfo = b.ExtraInfo
		FROM @tmp_TicketInfo tmp
			INNER JOIN bettrans b WITH(NOLOCK)
				ON tmp.TransId = b.TransId

		DELETE FROM @tmp_TicketInfo 
		WHERE Extrainfo NOT LIKE '%jtseqid%' OR bef_sid = sid

		SELECT @leagueId = m.leagueid FROM match m WITH(NOLOCK) WHERE m.matchid = @matchid

		SELECT @MatchID AS MatchId, @leagueId AS LeagueId, transid, custid , Extrainfo
				, CASE  WHEN sid IN (111,112,113) THEN 'Undo'
						WHEN sid = 103	THEN 'Void' 
				END [Action]
		FROM  @tmp_TicketInfo

		 UPDATE SystemSettings WITH(ROWLOCK,UPDLOCK) 
		 SET VValue = @CurrentLogID
		 WHERE VName = 'SiteDB_CO_LastLogId'
	
	END TRY
	BEGIN CATCH
		SELECT	@ErrMsg   = @ErrMsg + ISNULL(ERROR_MESSAGE(), '')
				,@ErrCode = @@error
         RETURN
	END CATCH
END

