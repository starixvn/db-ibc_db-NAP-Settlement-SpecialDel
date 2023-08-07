/*<info serverAlias="DBSIC-bodb02" executers="" viewers="" isFunction="0"></info>*/

/*
    Created by: 20230727@Louisa
    Task: Migrate data for SiteDB3 Redmineid:#181595 
    DB: DBSIC-bodb02

	Revisions:
		- 20230727@Louisa: Update ticket on SITEDB3 by link server, follow DBTRANS Redmineid:#181595 

*/

---Run on SITEDB3

USE bodb02
GO


---Required input @tableName
DECLARE @TableName	VARCHAR(200)   ----bettrans , bettransRnG , bettransLC , bettransG , translog, bettransm , transfer 

SELECT COUNT(1) as cnt FROM CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK) WHERE TableName  = @TableName

-------------------------------------------------------
DECLARE @StartRow		INT = 1
		, @StopRow		INT 
		, @MaxRow		INT 
		, @Threshold	INT = 500
		, @debug_message VARCHAR(500)

SET @MaxRow = (SELECT MAX(ID) FROM dbo.CheckSum_MigrateSiteDB3_Temp WITH(NOLOCK) WHERE TableName = @TableName )
IF @Threshold >= @MaxRow
		SET @Threshold = @MaxRow

SET @StopRow = @Threshold

WHILE (@MaxRow IS NOT NULL)
	BEGIN
		IF @TableName = 'bettrans'
		BEGIN
			UPDATE site3
			SET	 status				= trans.status
				,winlost			= trans.winlost
				,awinlost			= trans.awinlost
				,mwinlost			= trans.mwinlost
				,playercomm			= trans.playercomm
				,comm				= trans.comm
				,acomm				= trans.acomm
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,spositiontaking	= trans.spositiontaking
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,comstatus			= trans.comstatus
				,oddsspread			= trans.oddsspread
				,ruben				= trans.ruben
				,statuswinlost		= trans.statuswinlost
				,modds				= trans.modds
				,sdiscount			= trans.sdiscount
				,scomm				= trans.scomm
				,swinlost			= trans.swinlost
				,statusID			= trans.statusID
				,winlostdate		= trans.winlostdate
			FROM bettrans site3 
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.TransId
				INNER JOIN DBCTG.bodb02.dbo.bettrans trans WITH (NOLOCK) ON trans.transid  = site3.transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransRnG'
		BEGIN
			UPDATE site3		
			SET  status				= trans.status
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,spositiontaking	= trans.spositiontaking
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,sdiscount			= trans.sdiscount
				,statusID			= trans.statusID
				,IsSum				= trans.IsSum
				,winlost			= trans.winlost
				,awinlost			= trans.awinlost
				,mwinlost			= trans.mwinlost
				,swinlost			= trans.swinlost
				,playercomm			= trans.playercomm
				,comm				= trans.comm
				,acomm				= trans.acomm
				,scomm				= trans.scomm	
				,winlostdate		= trans.winlostdate
			FROM bettransRnG site3 
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.TransId
				INNER JOIN DBCTG.bodb02.dbo.bettransRnG trans WITH (NOLOCK) ON trans.transid  = site3.transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransLC'
		BEGIN
			UPDATE site3
			SET  status				= trans.status
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,spositiontaking	= trans.spositiontaking
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,sdiscount			= trans.sdiscount
				,statusID			= trans.statusID
				,IsSum				= trans.IsSum
				,winlost			= trans.winlost
				,awinlost			= trans.awinlost
				,mwinlost			= trans.mwinlost
				,swinlost			= trans.swinlost
				,playercomm			= trans.playercomm
				,comm				= trans.comm
				,acomm				= trans.acomm
				,scomm				= trans.scomm
				,winlostdate		= trans.winlostdate
			FROM bettransLC site3 
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.TransId
				INNER JOIN DBCTG.bodb02.dbo.bettransLC trans WITH (NOLOCK) ON trans.transid  = site3.transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'bettransG'
		BEGIN
			UPDATE site3
			SET  status				= trans.status
				,winlost			= trans.winlost
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,awinlost			= trans.awinlost
				,mwinlost			= trans.mwinlost
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,playercomm			= trans.playercomm
				,comm				= trans.comm
				,acomm				= trans.acomm
				,statuswinlost		= trans.statuswinlost
				,ruben				= trans.ruben
				,spositiontaking	= trans.spositiontaking
				,swinlost			= trans.swinlost
				,sdiscount			= trans.sdiscount
				,scomm				= trans.scomm
				,statusID			= trans.statusID
				,winlostdate		= trans.winlostdate
			FROM bettransG site3
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.TransId
				INNER JOIN DBCTG.bodb02.dbo.bettransG trans WITH (NOLOCK) ON trans.transid  = site3.transid
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'translog'
		BEGIN
			UPDATE site3
			SET  status				= trans.status
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,spositiontaking	= trans.spositiontaking
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,sdiscount			= trans.sdiscount
				,statusID			= trans.statusID
				,checkCount			= trans.checkCount
				,winlostdate		= trans.winlostdate
			FROM translog site3
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.translogid
				INNER JOIN DBCTG.bodb02.dbo.translog trans WITH (NOLOCK) ON trans.translogid  = site3.translogid 
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END
		
		ELSE IF @TableName = 'bettransm'
		BEGIN
			UPDATE site3
			SET  status				= trans.status
				,winlost			= trans.winlost
				,comstatus			= trans.comstatus
				,betfrom			= trans.betfrom
				,apositiontaking	= trans.apositiontaking
				,mpositiontaking	= trans.mpositiontaking
				,tpositiontaking	= trans.tpositiontaking
				,awinlost			= trans.awinlost
				,mwinlost			= trans.mwinlost
				,playerdiscount		= trans.playerdiscount
				,discount			= trans.discount
				,adiscount			= trans.adiscount
				,playercomm			= trans.playercomm
				,comm				= trans.comm
				,acomm				= trans.acomm
				,isfinish			= trans.isfinish
				,statuswinlost		= trans.statuswinlost
				,ruben				= trans.ruben
				,spositiontaking	= trans.spositiontaking
				,swinlost			= trans.swinlost
				,sdiscount			= trans.sdiscount
				,scomm				= trans.scomm
				,statusID			= trans.statusID
				,winlostdate		= trans.winlostdate
			FROM bettransm site3
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.Transid
				INNER JOIN DBCTG.bodb02.dbo.bettransm trans WITH (NOLOCK) ON trans.Transid  = site3.Transid 
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE IF @TableName = 'transfer'
		BEGIN
			UPDATE site3
			SET  TransDate		= trans.TransDate
				,WinlostDate	= trans.WinlostDate
				,Bettype		= trans.Bettype
				,Stake			= trans.Stake
				,Actual_Stake	= trans.Actual_Stake
				,Winlost		= trans.Winlost
				,AWinlost		= trans.AWinlost
				,MWinlost		= trans.MWinlost
				,SWinlost		= trans.SWinlost
				,PlayerComm		= trans.PlayerComm
				,Comm			= trans.Comm
				,AComm			= trans.AComm
				,SComm			= trans.SComm
				,StatusId		= trans.StatusId
			FROM transfer site3
				INNER JOIN dbo.CheckSum_MigrateSiteDB3_Temp t WITH(NOLOCK) ON t.Transid = site3.Transid
				INNER JOIN DBCTG.bodb02.dbo.transfer trans WITH (NOLOCK) ON trans.Transid  = site3.Transid 
			WHERE t.ID BETWEEN @StartRow AND @StopRow
				AND t.TableName = @TableName 
		END

		ELSE
			BREAK

		SET @debug_message = CONVERT(VARCHAR(50), GETDATE(), 121)			
		RAISERROR (@debug_message, 0, 1) WITH NOWAIT
		
		IF @StopRow = @MaxRow BREAK

		WAITFOR DELAY '00:00:00.180'

		SET @StartRow = @StopRow + 1
		SET @StopRow = @StopRow + @Threshold

		IF @StopRow >= @MaxRow
			SET @StopRow = @MaxRow

	END



