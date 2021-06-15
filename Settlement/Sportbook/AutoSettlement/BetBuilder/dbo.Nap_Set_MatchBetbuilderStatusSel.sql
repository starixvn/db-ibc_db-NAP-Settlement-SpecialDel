 /*<info serverAlias="DBACC-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[Nap_Set_MatchBetbuilderStatusSel]	
 			
 AS
/*
	Created by: 20190103@Vicky
	Task: Incorporate BetBuilder 
	DB: DBACC.BODB02
	
	Revisions:
		- 20190103@Vicky: Incorporate BetBuilder  [Redmine:#106903]
		- 20200803@July: Edit sporttype in (1,2) --1: soccer, 2:basketball
		- 20210615@Louisa: Turning SP [Redmine:#156987]	
		
	Param's Explanation:	
		
				
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistRunning BIT = 0
	DECLARE @tblMatch TABLE (MatchID INT)
	----------------------------------------------------------------------------
	
	INSERT INTO @tblMatch(MatchID)
	SELECT m.MatchID
	FROM dbo.match m WITH(NOLOCK)
		INNER JOIN dbo.VendorStatus vs WITH(NOLOCK) ON m.matchid = vs.matchid
		CROSS APPLY (SELECT TOP 1 1 AS valid FROM dbo.SMP_Market mk WITH (NOLOCK) WHERE mk.MatchId = m.matchid AND mk.ResultStatusId NOT IN (2,5)) AS temp
	WHERE m.eventstatus = 'completed'
			AND m.sporttype IN (1,2)
			AND vs.opened = 1			
			AND vs.VendorID = 34
			AND DATEDIFF(mi, ISNULL(m.Settletime, GETDATE()), GETDATE()) > 60
	
	IF @@ROWCOUNT > 0
	BEGIN	
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
			
		ELSE 
		SELECT @isExistRunning = 0
	END
		
	SELECT @isExistRunning as isExistRunning
		
END
GO
