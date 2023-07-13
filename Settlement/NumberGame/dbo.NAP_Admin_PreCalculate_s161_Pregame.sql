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
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @modds MONEY
		, @strTransIds VARCHAR(MAX)
		, @IsCentral BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	DECLARE @subtable_CAL_Deadball TABLE(transid BIGINT, modds MONEY, OddsType SMALLINT)

	CREATE TABLE #TempData_CAL_Deadball(transid BIGINT, modds MONEY, betteam NVARCHAR(10), hdp1 SMALLMONEY, bettype SMALLINT, OddsType TINYINT)

	INSERT INTO #TempData_CAL_Deadball(transid, modds, betteam, hdp1, bettype, OddsType)
	SELECT transid, modds, betteam, hdp1, bettype, CASE WHEN bettype IN (90) THEN 1 ELSE 0 END AS OddsType 
	FROM dbo.bettrans WITH(ROWLOCK)		
	WHERE matchid = @MatchId
		AND bettype = @BetType
		AND liveindicator = 0		
		AND statusID NOT IN (101,102) -- VOID, REJECT
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END

	IF @@ROWCOUNT = 0 RETURN

	UPDATE #TempData_CAL_Deadball
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
		DELETE @subtable_CAL_Deadball

		DELETE TOP (2000) #TempData_CAL_Deadball
		OUTPUT deleted.transid, deleted.modds, deleted.OddsType	
		INTO @subtable_CAL_Deadball(transid, modds, OddsType)	
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @strTransIds 		= (SELECT transid		AS '@t'
											,modds		AS '@m'
											,OddsType	AS '@ot'
								   FROM @subtable_CAL_Deadball
								   FOR XML PATH('r'), ROOT( 'root' ))
		
		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'CAL'
			   ,@strTransIds		 = @strTransIds
			   ,@Is3rd				 = 1
			   
	END

	DROP TABLE #TempData_CAL_Deadball
	
END
GO



