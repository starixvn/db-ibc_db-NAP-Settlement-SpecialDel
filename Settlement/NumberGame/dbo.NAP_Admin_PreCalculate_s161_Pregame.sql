ALTER PROCEDURE [NAP_Admin_PreCalculate_s161_Pregame] 
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

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @IgnoreList VARCHAR(200)
	SET @IgnoreList = 'DB04,DB042,DB043,DB044'

	DECLARE @modds MONEY, @winningOdds MONEY, @commWinRate SMALLMONEY, @commLostRate SMALLMONEY
	DECLARE @_xml XML, @_sXML VARCHAR(MAX)
		--,@LASCommand NVARCHAR(max)
		,@createdDate DATETIME--, @Remark varchar(500)

	DECLARE @subtable TABLE(transid BIGINT, winlost MONEY, awinlost MONEY, mwinlost MONEY, swinlost MONEY,
		playercomm MONEY, comm MONEY, acomm MONEY, scomm MONEY, statusid TINYINT, modds MONEY)

	SELECT transid, actual_stake, stake, odds, comstatus, modds, betteam, hdp1, hdp2, livehomescore, liveawayscore,
		apositiontaking, mpositiontaking, spositiontaking, playerdiscount,discount, adiscount, sdiscount,
		WinLost, aWinLost, mWinLost, sWinLost, PlayerComm, comm, acomm, scomm, StatusID, bettype
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
		,@winningOdds = CASE 
			WHEN odds<0 THEN 1 
			ELSE CASE WHEN bettype = 90 THEN odds-1 ELSE odds END
			END
		,WinLost = CASE
			WHEN @modds = 1  	THEN actual_stake + stake * @winningOdds
			WHEN @modds =  0	THEN actual_stake
			WHEN @modds = -1	THEN 0
			END
		,aWinLost = CASE
			WHEN @modds = 1		THEN stake * @winningOdds * -apositiontaking
			WHEN @modds =  0	THEN 0
			WHEN @modds = -1	THEN actual_stake * apositiontaking
			END
		,mWinLost = CASE
			WHEN @modds = 1 	THEN stake * @winningOdds * -mpositiontaking
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1 	THEN actual_stake * mpositiontaking
			END
		,sWinLost = CASE
			WHEN @modds = 1 	THEN stake * @winningOdds * -spositiontaking
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1 	THEN actual_stake * spositiontaking
			END

		,PlayerComm = CASE
			WHEN @modds = 1 	THEN playerdiscount * stake
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1 	THEN playerdiscount * stake
			END
		,Comm = CASE
			WHEN @modds = 1 	THEN discount * stake * (1-apositiontaking)
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1 	THEN discount * stake * (1-apositiontaking)
			END
		,aComm = CASE
			WHEN @modds = 1 	THEN adiscount * stake * (1-(mpositiontaking+apositiontaking))
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1 	THEN adiscount * stake * (1-(mpositiontaking+apositiontaking))
			END
		,sComm = CASE
			WHEN @modds = 1  	THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
			WHEN @modds =  0    THEN 0
			WHEN @modds = -1  	THEN sdiscount * stake * (1-(spositiontaking+mpositiontaking+apositiontaking))
			END
		,StatusID = CASE
			WHEN @modds = 1 THEN 112 --WON
			WHEN @modds = 0 THEN 111 --DRAW
			WHEN @modds = -1 THEN 113 --LOSE
			END

	WHILE (1 = 1)
	BEGIN
		DELETE @subtable

		--SELECT @LASCommand = '',
		--		@Remark = ''

		DELETE TOP (20) #TempData
		OUTPUT deleted.transid, deleted.winlost, deleted.awinlost, deleted.mwinlost, deleted.swinlost, 	
			deleted.playercomm, deleted.comm, deleted.acomm, deleted.scomm, deleted.statusid, deleted.modds	
		INTO @subtable(transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds)	

		IF @@ROWCOUNT = 0 BREAK

		SET @_xml = (
				SELECT transid '@q'
					,NULLIF(winlost, 0) '@a'
					,NULLIF(awinlost, 0) '@z'
					,NULLIF(mwinlost, 0) '@w'
					,NULLIF(swinlost, 0) '@s'
					,NULLIF(playercomm, 0) '@x'
					,NULLIF(comm, 0) '@e'
					,NULLIF(acomm, 0) '@d'
					,NULLIF(scomm, 0) '@c'
					,statusid '@r'
					,NULLIF(modds, 0) '@f'
				FROM @subtable
				FOR XML PATH('r'), ROOT('root'), TYPE
				)

		SELECT @_sXML = CONVERT(VARCHAR(max), @_xml)

		EXEC dbo.Bet_ExecRep_05 @IgnoreList = @IgnoreList
			,@updatetype = 1 -- calculate
			,@_sXML = @_sXML

		----- LAS settlement
		--SELECT @LASCommand = 'EXEC [dbo].[Admin_Calculate_s161_Pregame] @_sXML = ''' + @_sXML + ''''
		--		,@createdDate = GETDATE()

		--BEGIN TRY
		--	EXEC DBLAS.LASDB.[dbo].[Las_GeneratingSettlementCommand] @SPName = 'Admin_Calculate_s161_Pregame'
		--		,@SQLCommand = @LASCommand
		--		,@CreatedDate = @createdDate
		--		,@StatusID = 0 -- waiting
		--		,@MatchID = @matchid
		--		,@Bettype = NULL
		--		,@Status = 'waiting'
		--		,@BetCount = NULL
		--END TRY
		--BEGIN CATCH			
		--	SELECT @Remark = @Remark + CAST(transid as varchar(20)) + ','
		--	FROM @subtable

		--	SET @Remark = SUBSTRING(@Remark, 1, LEN(@Remark)-1)

		--	BEGIN TRY			
		--		EXEC DBLOG.bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
		--						@UserID = NULL, 
		--						@Matchid = @matchid, 
		--						@ActionID = 40014, 
		--						@Remark = @Remark
		--	END TRY
		--	BEGIN CATCH
		--		EXEC bodb_CustomerLog.dbo.LAS_WriteLog_UserLog_RunSP
		--						@UserID = NULL, 
		--						@Matchid = @matchid, 
		--						@ActionID = 40014, 
		--						@Remark = @Remark
		--	END CATCH
		--END CATCH
	END

	DROP TABLE #TempData
		
	-- LOG
	DECLARE	@LogData VARCHAR(1000)
	SET @LogData = 'NAP_Admin_PreCalculate_s161_Pregame MatchID:' + CONVERT(VARCHAR(20),@MatchId) + ' Bettype:' + CONVERT(VARCHAR(20),@BetType) +' Betteam:' +@BetTeam
	
	EXEC dbo.WriteLog_UserLog @UserID = 161, @Doing = @LogData
END

GO

GRANT EXECUTE ON [NAP_Admin_PreCalculate_s161_Pregame] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Admin_PreCalculate_s161_Pregame] TO [vnteam] AS [dbo]
GO


