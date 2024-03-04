/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Admin_PreCalculate_s161_Live @matchid INT
	,@DrawSeq TINYINT
	,@Number TINYINT
	,@Color VARCHAR(1)
	,@AdminID INT			= 148
	,@ErrCode INT			= 0 OUTPUT
	,@ErrMsg NVARCHAR(200)	= '' OUTPUT
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
		- 20230905@Aries: Set Max Payout for Non-sports Products [Redmine:#193259]
		- 20240201@Aries: Enhance diff balance for Number Game [Redmine:#200328]
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @modds MONEY
			,@strTransIds VARCHAR(MAX)
			,@IsCentral BIT = 0
			,@SiteDBGroupId			SMALLINT
			,@TransInfoMaxPO		VARCHAR(MAX)
			,@TotalTransMaxPO		INT = 0
			,@batchPO				SMALLINT = 500
			,@odds					SMALLMONEY
		
	DECLARE @subtable_CAL_Live TABLE(transid BIGINT, modds MONEY, OddsType SMALLINT, winlost MONEY, actualPO MONEY, IsApplyMaxPO BIT)

	CREATE TABLE #TempData_CAL_Live(transid BIGINT, modds MONEY, betteam NVARCHAR(10), hdp1 SMALLMONEY, bettype SMALLINT, betid BIGINT, OddsType TINYINT
										,custid INT, currency TINYINT, actualPO MONEY, winlost MONEY, IsApplyMaxPO BIT
										,transdate DATETIME, isFinish BIT,actual_stake MONEY, stake MONEY, odds SMALLMONEY
	)
	DECLARE @tmpMaxWinLimit	TABLE( CustId INT, MaxWinLimit MONEY)
	DECLARE @tmpTransIDMaxPO TABLE (TransID BIGINT
		,custid INT, actualPO MONEY, winlost MONEY
		,transdate DATETIME, bettype SMALLINT
	)

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	SELECT @SiteDBGroupId = (SELECT dbo.f_Get_SiteDBGroupID())

	INSERT INTO #TempData_CAL_Live(transid, modds, betteam, hdp1, bettype, betid, OddsType,custid,currency,transdate,actual_stake,stake,odds)
	SELECT transid, modds, betteam, hdp1, bettype, betid, CASE WHEN bettype IN (89,90) THEN 1 ELSE 0 END AS OddsType,custid,currency,transdate,actual_stake,stake,odds			
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
		modds = @modds,
		@odds = (CASE WHEN odds < 0 THEN 1 
	   				  WHEN oddstype = 1 THEN odds - 1 
					  ELSE odds END),
		actualPO = CASE
						WHEN @modds =  1 THEN actual_stake + stake * @odds
						ELSE NULL
					END 
	
	IF EXISTS (SELECT TOP 1 1 FROM dbo.f_NAP_Site_MaxPayoutSetting() WHERE SiteDBGroupId = @SiteDBGroupId)
	BEGIN
		;WITH cteCustIds
		AS(
			SELECT DISTINCT custid, currency
			FROM	#TempData_CAL_Live t
			WHERE	modds >= 1
		)
		INSERT INTO @tmpMaxWinLimit (CustId, MaxWinLimit)
		SELECT	t.custid, fc.MaxWinLimit
		FROM	CustDB.dbo.Customer c WITH(NOLOCK)
			INNER JOIN cteCustIds t
				ON t.custid = c.custid
			INNER JOIN CustDB.dbo.Site s WITH(NOLOCK)
				ON s.site = c.site
			INNER JOIN dbo.f_NAP_Site_MaxPayoutSetting() fs
				ON s.siteid = fs.siteid
			INNER JOIN dbo.f_NAP_Currency_MaxPayoutSetting() fc
				ON	t.currency = fc.ExchangeId
					AND fc.SiteDBGroupId = @SiteDBGroupId

		IF @@ROWCOUNT > 0
		BEGIN
			UPDATE t 
				SET IsApplyMaxPO = 1
					,winlost = m.MaxWinLimit
			FROM	#TempData_CAL_Live t
				INNER JOIN	@tmpMaxWinLimit m
					ON t.CustId = m.CustId
			WHERE	t.actualPO > m.MaxWinLimit

			SET @TotalTransMaxPO = @@ROWCOUNT
		END
			
	END

	WHILE (1 = 1)
	BEGIN
		DELETE @subtable_CAL_Live

		UPDATE TOP(2000) t
		SET t.isFinish = 1
		OUTPUT deleted.transid, deleted.modds, deleted.OddsType, deleted.winlost, deleted.actualPO, deleted.IsApplyMaxPO
		INTO @subtable_CAL_Live(transid, modds, OddsType , winlost, actualPO, IsApplyMaxPO)	
		FROM  #TempData_CAL_Live AS t
		WHERE t.isFinish IS NULL
		
		IF @@ROWCOUNT = 0 BREAK
		
		SET @strTransIds 		= (SELECT transid		AS '@t'
											,modds		AS '@m'
											,OddsType	AS '@ot'
											,CASE WHEN IsApplyMaxPO = 1 THEN winlost ELSE NULL END AS '@wl'
											,CASE WHEN IsApplyMaxPO = 1 THEN actualPO ELSE NULL END AS '@apo'
											,IsApplyMaxPO AS '@iMPO'
								   FROM @subtable_CAL_Live
								   FOR XML PATH('r'), ROOT( 'root' ))
								   
		EXEC dbo.NAP_Admin_Calculate_OtherSports
				@matchid			 = @matchid
			   ,@action				 = 'CAL'
			   ,@strTransIds		 = @strTransIds
			   ,@Is3rd				 = 1
			   ,@IsCalculateBalance	 = 1
			   ,@CWLBettype			 = 81
			   ,@BalanceType		 = 4
	END

	WHILE (@TotalTransMaxPO > 0)
	BEGIN
		IF @TotalTransMaxPO > @batchPO
		BEGIN
			DELETE @tmpTransIDMaxPO

			DELETE TOP (@batchPO) t
			OUTPUT deleted.custid, deleted.winlost, deleted.actualPO, deleted.transdate, deleted.bettype, deleted.transid 
			INTO @tmpTransIDMaxPO(custid, winlost, actualPO, transdate, bettype, transid)
			FROM	#TempData_CAL_Live t
			WHERE	IsApplyMaxPO = 1

			SET @TransInfoMaxPO = CAST((
									SELECT	TOP (@batchPO) CustId AS a1
											,161 AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminID AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	@tmpTransIDMaxPO
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END
		ELSE
		BEGIN
			SET @TransInfoMaxPO = CAST((
									SELECT	CustId AS a1
											,161 AS a2 -- productid
											,0 AS a3 -- groupid
											,winlost AS a4 -- maxwinlimit
											,actualPO AS a6 -- winamt
											,255 AS a7 -- levelid
											,255 AS a8 -- actionid
											,@AdminID AS a12 -- createdby
											,transdate AS a13 -- winlostdate
											,bettype AS a16
											,transid AS a17
									FROM	#TempData_CAL_Live
									WHERE	IsApplyMaxPO = 1
									FOR XML PATH('r'), ROOT('root')
							) AS VARCHAR(MAX))
		END

		SET @TotalTransMaxPO = @TotalTransMaxPO - @batchPO

		BEGIN TRY
			EXEC DBCUST.CustDB.dbo.Task_Winlimit_InsertHistoryData
				@XmlData = @TransInfoMaxPO
		END TRY
		BEGIN CATCH
			SELECT	 @ErrCode = ERROR_NUMBER()
					,@ErrMsg = ERROR_MESSAGE()				
		END CATCH
	END

	DROP TABLE #TempData_CAL_Live
END
GO



