/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_PreCalculate_s161_Live @matchid INT
	,@DrawSeq TINYINT
	,@Number TINYINT
	,@Color VARCHAR(1)
AS
/*
	Created by: Kathy
	Date:20131212
	Task: Settlement 
	Original SP: Admin_PreCalculate_s161_Live
	DB: DBTXN/BODB02
	
	Revisions:
		- 20140514@Kathy: insert settled command into LAS queue [Redmine:#14286]
		- 20151210@Patrick: Database - Change datatype [Redmine: #48660]
		- 20181203@Helen: Apply Service Broker for Other Sports - [Redmine:101611]
		- 20200218@Sol: : Incorporate Number Game - Color Ball [Redmine:#128203]
		- 20220711@Kathy: Do not use SELECT INTO [Redmine:#175276]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		- 20221011@Kathy: Split non-sport to another log table for sync service [Redmine:#178694]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @modds MONEY
			,@strTransIds VARCHAR(MAX)
			,@IsCentral BIT = 0
		
	DECLARE @subtable_CAL_Live TABLE(transid BIGINT, modds MONEY, OddsType SMALLINT)

	CREATE TABLE #TempData_CAL_Live(transid BIGINT, modds MONEY, betteam NVARCHAR(10), hdp1 SMALLMONEY, bettype SMALLINT, betid BIGINT, OddsType TINYINT)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	INSERT INTO #TempData_CAL_Live(transid, modds, betteam, hdp1, bettype, betid, OddsType)
	SELECT transid, modds, betteam, hdp1, bettype, betid, CASE WHEN bettype IN (89,90) THEN 1 ELSE 0 END AS OddsType 				
	FROM dbo.bettrans WITH(ROWLOCK)	
	WHERE matchid = @matchid 
		AND bettype IN (85, 86, 87, 89, 90, 91) 
		AND liveindicator = 1 
		AND statusID NOT IN (101, 102) -- VOID, REJECT
		AND SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE SiteDBGroupID END
		AND livehomescore + liveawayscore + CASE WHEN bettype = 87 THEN 2 ELSE 1 END = @DrawSeq

	IF @@ROWCOUNT = 0 RETURN
		
	UPDATE #TempData_CAL_Live
	SET @modds = CASE
			WHEN bettype = 85 AND betteam = N'h' AND @Number >= 38   THEN 1
			WHEN bettype = 85 AND betteam = N'a' AND @Number <= 37   THEN 1
			WHEN bettype = 86 AND betteam = N'h' AND @Number %2 = 1  THEN 1
			WHEN bettype = 86 AND betteam = N'a' AND @Number %2 = 0  THEN 1
			WHEN bettype = 87 AND betteam = N'h' AND @Number > betid THEN 1
			WHEN bettype = 87 AND betteam = N'a' AND @Number < betid THEN 1
			WHEN bettype = 89 AND betteam = N'1:1' AND @Number >= 38 AND @Number %2 = 1 THEN 1 -- OVER / ODD
			WHEN bettype = 89 AND betteam = N'1:2' AND @Number >= 38 AND @Number %2 = 0 THEN 1 -- OVER / EVEN
			WHEN bettype = 89 AND betteam = N'2:1' AND @Number <= 37 AND @Number %2 = 1 THEN 1 -- UNDER / ODD
			WHEN bettype = 89 AND betteam = N'2:2' AND @Number <= 37 AND @Number %2 = 0 THEN 1 -- UNDER / EVEN
			WHEN bettype = 90 AND HDP1 = 1 AND CEILING(@Number/5.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 2 AND CEILING(@Number/15.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 3 AND CEILING(@Number/25.0) = betteam THEN 1 
			WHEN bettype = 90 AND HDP1 = 4 AND @Number % 5 = CASE betteam WHEN 5 THEN 0 ELSE betteam END THEN 1 
			WHEN bettype = 90 AND HDP1 = 5 AND @Number = betteam	 THEN 1 
			WHEN bettype = 91 AND betteam = @Color THEN 1 
			ELSE -1 -- lose
			END,
		modds = @modds	

	WHILE (1 = 1)
	BEGIN
		DELETE @subtable_CAL_Live

		DELETE TOP (2000) #TempData_CAL_Live
		OUTPUT deleted.transid, deleted.modds, deleted.OddsType	
		INTO @subtable_CAL_Live(transid, modds, OddsType )	
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @strTransIds 		= (SELECT transid		AS '@t'
											,modds		AS '@m'
											,OddsType	AS '@ot'
								   FROM @subtable_CAL_Live
								   FOR XML PATH('r'), ROOT( 'root' ))
								   
		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'CAL'
			   ,@strTransIds		 = @strTransIds
			   ,@Is3rd				 = 1
	END

	DROP TABLE #TempData_CAL_Live
END
GO



