/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SMPSelectionDetailSel_Ticket]
	@matchID 			INT
AS
/*
	Created by: 20220719@Louisa
	Task: Scale Out BetTrans
	DB: DBTXN/BODB02
	
	Revisions:
		- 20220719@Louisa: Get ticket BB [Redmine:#175251]		
		
	Param's Explanation:


*/
BEGIN
	SET NOCOUNT ON
	
	
	DECLARE @tblMarketID TABLE (MarketID VARCHAR(20) NOT NULL PRIMARY KEY, IsRunning TINYINT)
	DECLARE @FixtureID VARCHAR(20)
			,@IsCentral BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
	----------------------------------------------------------------------------
	
	INSERT INTO @tblMarketID (MarketID, IsRunning)
	SELECT Betcheck AS MarketID
			,MAX(CASE WHEN statusID IN (0,1) THEN 1 ELSE 0 END) AS IsRunning
	FROM dbo.Bettrans bt WITH (NOLOCK)
	WHERE bt.matchID = @matchID 
		AND bt.Bettype = 38
		AND bt.StatusID NOT IN (101,102)
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
	GROUP BY Betcheck

	SELECT MarketID, IsRunning
	FROM @tblMarketID
	
END
GO

