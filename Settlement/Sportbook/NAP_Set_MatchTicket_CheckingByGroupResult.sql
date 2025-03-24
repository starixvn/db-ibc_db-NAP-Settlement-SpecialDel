/*<info serverAlias="DBCTG-bodb02,DBSID-bodb02,DBSIC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_MatchTicket_CheckingByGroupResult]
	 @Matchid INT
AS
/*
    Created by: 20250324@Aries
    Task: Sportsbook » SOP » Soccer » Phase 2 [Redmine:#220444]
    DB: DBTXN/BODB02 
    
    Revisions: 
		- 20250324@Aries: Created [Redmine:#220444]
*/
BEGIN
	SET NOCOUNT ON
    DECLARE @tmpBettype TABLE (Bettype SMALLINT, BetID INT, GroupResult VARCHAR(20))
    DECLARE @tmpGroupResult TABLE (GroupResult VARCHAR(20), Total INT)
    DECLARE  @IsCentral BIT = 0

    SET @IsCentral = [dbo].[f_CheckServerCentral]()

    INSERT INTO @tmpBettype(Bettype, BetID,GroupResult)
    SELECT Bettype, BetID, JSON_VALUE(sp.APSetting,'$."groupResult"')
    FROM SettlementSpecialBettypeProfile AS sp WITH (NOLOCK)
    WHERE sp.SportType = 1
        AND JSON_VALUE(sp.APSetting,'$."groupResult"') IS NOT NULL
    
    INSERT INTO @tmpGroupResult(GroupResult,Total)
    SELECT bt.GroupResult, COUNT(1) AS Total
    FROM bettrans AS b WITH(NOlOCK)
        INNER JOIN @tmpBettype AS bt ON  b.BetType = bt.BetType AND (bt.BetID = 0 OR b.BetID = bt.BetID) 
    WHERE b.matchid = @Matchid
        AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
    GROUP BY bt.GroupResult

    INSERT INTO @tmpGroupResult(GroupResult,Total)
    SELECT bt.GroupResult, COUNT(1) AS Total
    FROM bettransm AS bm WITH(NOlOCK)
        INNER JOIN @tmpBettype AS bt ON  bm.BetType = bt.BetType AND  (bt.BetID = 0 OR bt.BetID = bm.betcheck)
    WHERE bm.matchid = @Matchid
        AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
    GROUP BY bt.GroupResult

    SELECT GroupResult, SUM(Total) AS TotalTicket
    FROM @tmpGroupResult
    GROUP BY GroupResult

    
END
GO