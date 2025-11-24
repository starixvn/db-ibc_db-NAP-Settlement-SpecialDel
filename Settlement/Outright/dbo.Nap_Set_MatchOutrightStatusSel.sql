 /*<info serverAlias="DBACC-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
 ALTER PROCEDURE [dbo].[Nap_Set_MatchOutrightStatusSel]	
 			
 AS
/*
	Created by: 20251022@Hughie
	Task: Outright Enhance 
	DB: DBACC.BODB02
	
	Revisions:
		- 20251022@Hughie: Enhance Outright phase 3 [Redmine:#241793]
		- 20251124@Hughie: Enhance Outright phase 4 [Redmine:#244634]
		
	Param's Explanation:	

*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @isExistRunning BIT = 0
	DECLARE @tblOutright TABLE (Orid INT)
	----------------------------------------------------------------------------
	
	INSERT INTO @tblOutright(Orid)
	SELECT o.orid
	FROM dbo.outright o WITH(NOLOCK)
		CROSS APPLY (SELECT TOP 1 1 AS valid FROM dbo.ResultDetailOutright r WITH (NOLOCK) WHERE r.orid = o.orid AND r.ResultStatusId =3) AS temp
	WHERE o.oddsstatus <> 'completed'
	
	IF @@ROWCOUNT > 0
	BEGIN	
		IF EXISTS(
			SELECT TOP 1 1
			FROM @tblOutright o
				INNER JOIN dbo.Bettrans bt WITH(NOLOCK) ON o.Orid = bt.matchid
			WHERE bt.Bettype = 10
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
