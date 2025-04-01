/*<info serverAlias="DBACC-bodb02,DBAGE-bodb02,DBBOF-bodb02,DBTP-bodb02" executers="wsv_nap" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_SiteDB_SyncTransId_Upd]
	@TableName		VARCHAR(200)
	,@transInfoJson VARBINARY(MAX)	= NULL OUTPUT
	,@ErrCode		INT				= 0	 OUTPUT  
	,@ErrMsg		VARCHAR(300)	= '' OUTPUT
AS
/*
	Created by: 20240607@Kathy
	Task: Sync data  

	
	Revisions:
		- 20240607@Kathy: sync data [Redmine:#206272]
		- 20250401@Hughie: Extend data type of currency from tinyint to smallint [Redmine:#222173]

	Param's Explanation:  
		
*/
BEGIN
	DECLARE @Decompress_TransInfoJson NVARCHAR(MAX)
			,@batchNo INT

	DECLARE @tmpTransId TABLE (transId BIGINT, refno BIGINT
		,matchid INT, winlostdate DATETIME, betdaqid VARCHAR(50)
		,modds VARCHAR(11), odds SMALLMONEY, oddsid INT, oddsspread VARCHAR(20), statuswinlost VARCHAR(1),SettlementTime DATETIME
		,WinLost MONEY,aWinLost MONEY,mWinLost MONEY,sWinLost MONEY
		,PlayerComm MONEY, Comm MONEY,aComm MONEY,sComm MONEY
		,Status NVARCHAR(10),StatusID TINYINT,ruben TINYINT,FcUpdateTime DATETIME2, creator INT
		,hdp1 SMALLMONEY, hdp2 SMALLMONEY, livehomescore SMALLINT, liveawayscore SMALLINT
		,custid INT, bettype SMALLINT, userid INT , CreatedDate DATETIME, MarkType TINYINT, betid VARCHAR(50), ExtraInfo VARCHAR(1000)
		
		,transdate	 DATETIME 
		,comstatus NVARCHAR(40),checktime	DATETIME	
		,actualrate	FLOAT,recommend	INT	,mrecommend	INT	,srecommend	INT, stake MONEY,actual_stake MONEY	
		,currency	SMALLINT	
		,Username	NVARCHAR(100),CurrencyName	NVARCHAR(100),virtualrate FLOAT, MainMatchId INT
	)
	
	SET @Decompress_TransInfoJson = CAST(DECOMPRESS(@TransInfoJson) AS NVARCHAR(MAX))

	IF @TableName = 'bettrans'
	BEGIN
		INSERT INTO @tmpTransId (TransID
			,matchid, winlostdate, betdaqid
			,modds, odds, oddsid, oddsspread, statuswinlost,SettlementTime,WinLost,aWinLost
			,mWinLost,sWinLost,PlayerComm,Comm,aComm,sComm,Status,StatusID,ruben,FcUpdateTime
			, hdp1 , hdp2 , livehomescore , liveawayscore , creator, betid, ExtraInfo		
			,virtualrate	 
		)
		SELECT *
		FROM OPENJSON(@Decompress_TransInfoJson)
			WITH (
			t   BIGINT
			,mid INT
			,wld  SMALLDATETIME	
			,bdaq  VARCHAR(50)
			,m VARCHAR(11)
			,o SMALLMONEY
			,oid INT
			,os VARCHAR(20)
			,statuswl  VARCHAR(1)
			,st  DATETIME
			,w  MONEY
			,aw  MONEY
			,mw  MONEY
			,sw  MONEY
			,pc  MONEY
			,c  MONEY
			,ac  MONEY
			,sc  MONEY
			,s  NVARCHAR(10)
			,sid  TINYINT
			,r  TINYINT
			,rut DATETIME2
			,hdp1 SMALLMONEY
			,hdp2 SMALLMONEY
			,lh SMALLINT
			,la SMALLINT
			,cr INT
			,bid VARCHAR(50)
			,ex VARCHAR(1000)
			,v FLOAT
		)
		SET @batchNo = @@ROWCOUNT

		UPDATE TOP (@batchNo) b
			SET
				matchid = CASE WHEN t.matchid IS NULL THEN b.matchid ELSE t.matchid END
				,winlostdate = CASE WHEN t.winlostdate IS NULL THEN b.winlostdate ELSE t.winlostdate END
				,betdaqid = CASE WHEN t.betdaqid IS NULL THEN b.betdaqid ELSE CAST(t.betdaqid AS BIGINT) END
				,modds = CASE WHEN t.modds IS NULL THEN b.modds 
								WHEN t.modds = '' THEN NULL
								ELSE CAST(t.modds AS SMALLMONEY ) 
							END
				,odds = CASE WHEN t.odds IS NULL THEN b.odds ELSE t.odds END
				,oddsid = CASE WHEN t.oddsid IS NULL THEN b.oddsid ELSE t.oddsid END
				,oddsspread = CASE WHEN t.oddsspread IS NULL THEN b.oddsspread ELSE CAST(t.oddsspread AS MONEY) END  	
				,statuswinlost = CASE 
									WHEN t.statuswinlost IS NULL THEN b.statuswinlost
									WHEN t.statuswinlost = '' THEN NULL
									ELSE CAST(t.statuswinlost AS TINYINT)
								END
				,SettlementTime = CASE WHEN t.SettlementTime IS NULL THEN b.SettlementTime ELSE GETDATE() END						
				,WinLost = CASE WHEN t.WinLost IS NULL THEN b.winlost ELSE t.WinLost END
				,aWinLost = CASE WHEN t.aWinLost IS NULL THEN b.awinlost ELSE t.aWinLost END			
				,mWinLost = CASE WHEN t.mWinLost IS NULL THEN b.mwinlost ELSE t.mWinLost END
				,sWinLost = CASE WHEN t.sWinLost IS NULL THEN b.swinlost ELSE t.sWinLost END
				,PlayerComm = CASE WHEN t.PlayerComm IS NULL THEN b.playercomm ELSE t.PlayerComm END
				,Comm = CASE WHEN t.Comm IS NULL THEN b.comm ELSE t.Comm END					
				,aComm = CASE WHEN t.aComm IS NULL THEN b.acomm  ELSE t.aComm END					
				,sComm = CASE WHEN t.sComm IS NULL THEN b.scomm ELSE t.sComm END					
				,Status = CASE WHEN t.Status IS NULL THEN b.status ELSE t.Status END
				,StatusID = CASE WHEN t.StatusID IS NULL THEN b.statusID ELSE t.StatusID END
				,ruben= CASE WHEN t.ruben IS NULL THEN b.ruben ELSE t.ruben END
				,FcUpdateTime = CASE WHEN t.FcUpdateTime IS NULL THEN b.FcUpdateTime ELSE SYSDATETIME() END
				,hdp1 = CASE WHEN t.hdp1 IS NULL THEN b.hdp1 ELSE t.hdp1 END					
				,hdp2 = CASE WHEN t.hdp2 IS NULL THEN b.hdp2  ELSE t.hdp2 END					
				,livehomescore = CASE WHEN t.livehomescore IS NULL THEN b.livehomescore ELSE t.livehomescore END					
				,liveawayscore = CASE WHEN t.liveawayscore IS NULL THEN b.liveawayscore ELSE t.liveawayscore END									
				,creator = CASE WHEN t.creator IS NULL THEN b.creator ELSE t.creator END
				,betid = CASE WHEN t.betid IS NULL THEN b.betid ELSE CAST(t.betid AS BIGINT) END
				,ExtraInfo = CASE WHEN t.ExtraInfo IS NULL THEN b.ExtraInfo ELSE t.ExtraInfo END
				,virtualrate = CASE WHEN t.virtualrate IS NULL THEN b.virtualrate ELSE t.virtualrate END
						
		FROM @tmpTransId t
			INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) 
				ON  t.transid = b.transid 
		OPTION (OPTIMIZE FOR (@batchNo = 1), FORCE ORDER)
					
	END
	ELSE IF @TableName = 'bettransm'
	BEGIN
		INSERT INTO @tmpTransId (TransID, matchid
			,winlostdate, statuswinlost, refno, WinLost
			, Status, StatusID, ruben, hdp1, hdp2, livehomescore, liveawayscore, Creator
		)
		SELECT *
			FROM OPENJSON(@Decompress_TransInfoJson)
				WITH (
				t   BIGINT
				,mid INT
				,wld  SMALLDATETIME	
				,statuswl  VARCHAR(1)
				,ref BIGINT
				,w  MONEY
				,s  NVARCHAR(10)
				,sid  TINYINT
				,r  TINYINT
				,hdp1 SMALLMONEY
				,hdp2 SMALLMONEY
				,lh SMALLINT
				,la SMALLINT
				,cr INT
			)
		
		SET @batchNo = @@ROWCOUNT
		UPDATE TOP (@batchNo)  bm
			SET matchid = CASE WHEN t.matchid IS NULL THEN bm.matchid ELSE t.matchid END
				,ruben = CASE WHEN t.ruben IS NULL THEN bm.ruben ELSE t.ruben END								
					,winlostdate = CASE 
										WHEN t.winlostdate IS NULL THEN bm.winlostdate	
										WHEN t.winlostdate = '' THEN NULL
										ELSE t.winlostdate
									END
					,WinLost = CASE WHEN t.WinLost IS NULL THEN bm.winlost ELSE t.WinLost END
					,[status] = CASE WHEN t.Status IS NULL THEN bm.status ELSE t.Status END
					,statusID = CASE WHEN t.StatusID IS NULL THEN bm.statusID ELSE t.StatusID END								
					,statuswinlost = CASE 
										WHEN t.statuswinlost IS NULL THEN bm.statuswinlost
										WHEN t.statuswinlost = '' THEN NULL
										ELSE CAST(t.statuswinlost AS TINYINT)
									END
					,hdp1 = CASE WHEN t.hdp1 IS NULL THEN bm.hdp1 ELSE t.hdp1 END					
					,hdp2 = CASE WHEN t.hdp2 IS NULL THEN bm.hdp2  ELSE t.hdp2 END					
					,livehomescore = CASE WHEN t.livehomescore IS NULL THEN bm.livehomescore ELSE t.livehomescore END					
					,liveawayscore = CASE WHEN t.liveawayscore IS NULL THEN bm.liveawayscore ELSE t.liveawayscore END									
					,creator = CASE WHEN t.creator IS NULL THEN bm.creator ELSE t.creator END					
		FROM	@tmptransid t
			INNER JOIN dbo.bettransm bm WITH (ROWLOCK, UPDLOCK)
				ON	bm.transid = t.transid 
	END
END
GO