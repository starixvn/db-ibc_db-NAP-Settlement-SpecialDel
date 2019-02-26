 /*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[Nap_Set_MatchBetbuilderStatusSel]	
 			
 AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBTXN.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		
		
	Param's Explanation:	
		
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistRunning BIT
	DECLARE @tblMatch TABLE (MatchID INT)
	----------------------------------------------------------------------------
	
	INSERT INTO @tblMatch(MatchID)
	SELECT m.MatchID
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.VendorStatus vs WITH(NOLOCK) ON m.matchid = vs.matchid 
	WHERE m.eventstatus = 'completed'
			AND m.sporttype = 1
			AND vs.opened = 1			
			AND vs.VendorID = 34
			AND DATEDIFF(mi, ISNULL(m.Settletime, GETDATE()), GETDATE()) > 60
	
	
	IF EXISTS(
		SELECT TOP 1 1
		FROM @tblMatch m
			INNER JOIN dbo.Bettrans bt WITH(NOLOCK) ON m.matchid = bt.matchid
		WHERE bt.Bettype = 38
			AND bt.StatusID = 0				-- running
	)
	BEGIN
		SELECT @isExistRunning = 1
	END		
	ELSE SELECT @isExistRunning = 0
	
	SELECT @isExistRunning as isExistRunning
		
END
GO
