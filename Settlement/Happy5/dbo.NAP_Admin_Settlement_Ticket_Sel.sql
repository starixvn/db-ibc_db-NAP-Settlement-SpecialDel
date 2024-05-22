/*<info serverAlias="DBCTG-bodb02 , DBSIC-bodb02 , DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_Ticket_Sel
	 @MatchId					INT
	,@Sporttype					TINYINT
	,@Resources					VARCHAR(MAX)
	,@Action					VARCHAR(20)		= 'CAL'
	
	,@MinCustId					INT
	,@MinCustId_MinTransID		BIGINT
	,@MinCustId_MaxTransID		BIGINT

	,@MaxCustId					INT
	,@MaxCustId_MinTransID		BIGINT
	,@MaxCustId_MaxTransID		BIGINT
AS
/*
	Created by: 20240520@Aries
	Task: Transfer the logic business from the DB layer to the Application layer for Happy5 [Redmine:#202389]
	DB: DBTXN/bodb02

	Revisions:
		- 20240520@Aries: Created  [Redmine:#202389]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON
	DECLARE @IsCentral			BIT = 0	

	DECLARE @tmpBettype			TABLE(pfID SMALLINT, BetType SMALLINT, BetID BIGINT PRIMARY KEY (BetType,BetID))

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO @tmpBettype(pfID,BetType,BetID)
	SELECT DISTINCT p.pfID,p.Bettype,p.BetID
	FROM STRING_SPLIT(@Resources,',') AS r
		INNER JOIN SettlementSpecialBettypeProfile p WITH(NOLOCK) ON r.value = p.ResourceID AND p.sporttype = @Sporttype

	IF @Action = 'CAL' AND @MinCustId = @MaxCustId
	BEGIN
		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MinCustId
			AND b.TransId BETWEEN  @MinCustId_MinTransID AND @MinCustId_MaxTransID
			AND b.statusID NOT IN (101,102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	END

	IF @Action = 'CAL' AND @MinCustId != @MaxCustId
	BEGIN
		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MinCustId
			AND b.TransId BETWEEN  @MinCustId_MinTransID AND @MinCustId_MaxTransID
			AND b.statusID NOT IN (101,102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

		UNION ALL

		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid > @MinCustId AND b.custid < @MaxCustId
			AND b.statusID NOT IN (101,102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
		UNION ALL

		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MaxCustId
			AND b.TransId BETWEEN  @MaxCustId_MinTransID AND @MaxCustId_MaxTransID
			AND b.statusID NOT IN (101,102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	END
	
	IF @Action = 'REFUND' AND @MinCustId = @MaxCustId
	BEGIN
		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MinCustId
			AND b.TransId BETWEEN  @MinCustId_MinTransID AND @MinCustId_MaxTransID
			AND	b.statusID NOT IN (103, 101, 102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

	END

	IF @Action = 'REFUND' AND @MinCustId != @MaxCustId
	BEGIN
		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MinCustId
			AND b.TransId BETWEEN  @MinCustId_MinTransID AND @MinCustId_MaxTransID
			AND	b.statusID NOT IN (103, 101, 102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

		UNION ALL

		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake 
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid > @MinCustId AND b.custid < @MaxCustId
			AND	b.statusID NOT IN (103, 101, 102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
		
		UNION ALL

		SELECT b.transid
			  ,b.custid
			  ,bt.pfID AS ProfileId ,b.bettype,b.betid
			  ,b.betteam,b.hdp1,b.hdp2,b.transdesc
			  ,b.currency
			  ,b.odds,b.oddsspread
			  ,b.Status,b.statusID,b.statuswinlost
			  ,b.stake,b.actual_stake AS actualStake
			  ,b.comstatus
			  ,b.WinLost
			  ,b.aWinLost,b.apositiontaking
			  ,b.mWinLost,b.mpositiontaking
			  ,b.sWinLost,b.spositiontaking
			  ,b.PlayerComm,b.playerdiscount
			  ,b.Comm,b.discount
			  ,b.aComm,b.adiscount
			  ,b.sComm,b.sdiscount
			  ,b.ruben
			  ,b.ExtraInfo
			  ,b.transdate,b.SettlementTime
		FROM bettrans AS b WITH(NOLOCK,INDEX(CIX_matchid_bettype)) 
			CROSS APPLY(SELECT TOP 1 tbt.pfID FROM @tmpBettype AS tbt WHERE b.BetType = tbt.BetType) AS bt
		WHERE b.matchid = @MatchId 
			AND b.custid = @MaxCustId
			AND b.TransId BETWEEN  @MaxCustId_MinTransID AND @MaxCustId_MaxTransID
			AND	b.statusID NOT IN (103, 101, 102)
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
	END
	
END
GO
