/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_FastMarket_MatchSelDetail_Ticket] 
	@MatchId	INT
AS
/*
	 Created by: 20220719@Louisa
     Task: Scale Out BetTrans [Redmine:#175251]
     DB: DBTXN/BODB02 
	
	Revisions:
		- 20220719@Louisa: Initial- Get ResourceId and Count ticket Status [Redmine:#175251]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @tblFMBettype TABLE (BetType SMALLINT PRIMARY KEY, ResourceId VARCHAR(20))

	CREATE TABLE #tblBettrans (TransId BIGINT, BetType SMALLINT, hdp1 SMALLMONEY, statusId TINYINT, isMarked BIT DEFAULT(0))
	CREATE INDEX IX_tblBettrans_bettype ON #tblBettrans (BetType)
	
	INSERT INTO @tblFMBettype(bettype, ResourceId)
	SELECT	BetType
			,CAST(BetType AS VARCHAR) + '__' AS ResourceId -- 22X__
	FROM	dbo.f_Set_GetGroupBettypes()
	WHERE	GroupId = 9	
 	
	INSERT INTO #tblBettrans(TransId, bettype, hdp1, statusId)
	SELECT	b.transid, bettype, hdp1, statusID
	FROM	dbo.bettrans b WITH(NOLOCK)
	WHERE	matchid = @matchid
			AND EXISTS(SELECT TOP 1 1 FROM @tblFMBettype WHERE bettype = b.bettype)
	
	UPDATE b 
		SET isMarked = 1
	FROM	#tblBettrans b
		INNER JOIN dbo.MarkedTransaction mt WITH(NOLOCK)
			ON b.TransId = mt.TransId

	SELECT	9 AS GroupId
		,SUM(CASE WHEN statusId = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS betRunningCount
		,SUM(CASE WHEN statusId BETWEEN 111 AND 113 OR statusId = 103 THEN 1 ELSE 0 END) AS betSettledCount
		,SUM(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS betMarkedCount
	FROM	#tblBettrans

	-- result detail of each bettype
	;WITH  betstatus AS (
		SELECT	bettype
				, hdp1 AS Position
				, SUM(CASE WHEN StatusID IN (101, 102) THEN 0 ELSE 1 END) AS TicketCount
				, MAX(CASE WHEN StatusID = 0 AND isMarked = 0 THEN 1 ELSE 0 END) AS TicketRunning
				, MAX(CASE WHEN statusId BETWEEN 0 AND 1 AND isMarked = 1 THEN 1 ELSE 0 END) AS TicketMarked
		FROM	#tblBettrans
		GROUP BY bettype, hdp1
	)
	SELECT	BetType  
			,CASE WHEN b.BetType NOT IN (228, 229) THEN b.Position 
				  ELSE CASE 
							WHEN b.Position <= 44 THEN b.Position
							WHEN b.Position >= 47 THEN b.Position - 1
							ELSE -1 -- injury time
						END
			  END AS Position
			,TicketCount
			,TicketRunning
			,TicketMarked
	FROM	betstatus b  



END
GO
