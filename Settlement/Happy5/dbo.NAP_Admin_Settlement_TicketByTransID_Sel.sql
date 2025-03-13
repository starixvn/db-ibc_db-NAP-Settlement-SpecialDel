/*<info serverAlias="DBCTG-bodb02 , DBSIC-bodb02 , DBSID-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_Settlement_TicketByTransID_Sel
	@TransIDs					VARCHAR(MAX)
   ,@Sporttype					TINYINT
AS
/*
	Created by: 20240918@Aries
	Task: Created [Redmine:#210875]
	DB: DBTXN/bodb02

	Revisions:
		- 20240918@Aries: Betradar VS - Integrate 2 new sports Virtual Horse Racing & Virtual Dog Racing  [Redmine:#210875]
		- 20240312@Jane: Integration VS7 - Kiron [Redmine:#219147]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IsCentral			BIT
	DECLARE @tblTransID			TABLE(TransID BIGINT)

	SET @IsCentral = [dbo].[f_CheckServerCentral]()

	INSERT INTO @tblTransID(TransID)
	SELECT value AS TransID
	FROM STRING_SPLIT(@TransIDs,',')

	SELECT b.transid
		  ,b.custid
		  ,bt.pfID AS ProfileId ,b.bettype--,b.betid
		  ,b.betteam,b.transdesc -- ,b.hdp1,b.hdp2
		  ,b.currency
		  ,b.oddsid
		  ,b.odds--,b.oddsspread
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
		  ,b.transdate
		  ,b.SiteDBGroupID
	FROM @tblTransID AS t
		INNER JOIN dbo.bettrans b  WITH (NOLOCK) ON  t.transid = b.transid
		CROSS APPLY(SELECT TOP 1 p.pfID 
					FROM SettlementSpecialBettypeProfile AS p WITH(NOLOCK)
					WHERE b.BetType = p.BetType
						AND p.sporttype = @Sporttype
					) AS bt
	WHERE b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END

END
GO
