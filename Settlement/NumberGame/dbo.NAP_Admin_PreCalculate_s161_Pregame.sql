/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_PreCalculate_s161_Pregame
	@MatchId INT
	,@BetType SMALLINT
	,@BetTeam NVARCHAR(1)
	,@FirstBallNo INT = 0
AS
/*
	Created by: Kathy
	Date: 20131212
	Task: Settlement 
	Original SP: Admin_PreCalculate_s161_Pregame
	DB: DBTXN/BODB02				

	Revisions:		
		- 20140513@Kathy: insert settled command into LAS queue [Redmine:#14286]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20181203@Helen: Apply Service Broker for Other Sports - [Redmine:101611]

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @modds MONEY

	DECLARE @subtable TABLE(transid BIGINT, modds MONEY, OddsType SMALLINT)

	SELECT transid, modds, betteam, hdp1, bettype, CASE WHEN bettype IN (90) THEN 1 ELSE 0 END AS OddsType 
	INTO #TempData				
	FROM dbo.bettrans WITH(ROWLOCK)		
	WHERE matchid = @MatchId
		AND bettype = @BetType
		AND liveindicator = 0		
		AND statusID NOT IN (101,102) -- VOID, REJECT

	IF @@ROWCOUNT = 0 RETURN

	UPDATE #TempData
	SET @modds = CASE
			WHEN bettype = 90 AND HDP1 = 1 AND CEILING(@FirstBallNo/5.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 2 AND CEILING(@FirstBallNo/15.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 3 AND CEILING(@FirstBallNo/25.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 4 AND (@FirstBallNo%5 = CASE betteam WHEN 5 THEN 0 ELSE betteam END) THEN 1 
			WHEN bettype = 90 AND HDP1 = 5 AND @FirstBallNo = betteam	 THEN 1 
			WHEN bettype in (81,82,83,84,85,86,88) AND @BetTeam = 'x' THEN 0 --draw
			WHEN bettype in (81,82,83,84,85,86,88) AND @BetTeam = betteam THEN 1
			ELSE -1 -- lose
			END
		,modds = @modds
		
	WHILE (1 = 1)
	BEGIN
		DELETE @subtable


		DELETE TOP (2000) #TempData
		OUTPUT deleted.transid, deleted.modds, deleted.OddsType	
		INTO @subtable(transid, modds, OddsType)	

		IF @@ROWCOUNT = 0 BREAK

		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'CAL'
			   ,@strTransIds		 = @strTransIds
	END

	DROP TABLE #TempData
		
	-- LOG
	DECLARE	@LogData VARCHAR(1000)
	SET @LogData = 'NAP_Admin_PreCalculate_s161_Pregame MatchID:' + CONVERT(VARCHAR(20),@MatchId) + ' Bettype:' + CONVERT(VARCHAR(20),@BetType) +' Betteam:' +@BetTeam
	
	EXEC dbo.WriteLog_UserLog @UserID = 161, @Doing = @LogData
	
END
GO



