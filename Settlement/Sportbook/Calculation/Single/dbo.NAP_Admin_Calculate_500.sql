/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction=""></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_500] 
	@MatchId	INT
	,@Action	VARCHAR(20)
	,@CustIds	VARCHAR(MAX) = ''
AS
/*
		Created: Kathy
		Date: 20160112
		Task: Calculating charged commission
			NOTE: This is NOT execRep SP
		DB: DBTXN/bodb02
		
		Revisions:
			- 20220315@Kathy: Change to use STRING_SPLIT [Redmine:#166454]
			- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
			
			
		Parameter's Explanation:
			@Action: CAL, CAL-FT, REFUND-FT, REFUND, UNDO
			@CustIds: IMBC Cust List
								
*/ 
BEGIN
	SET NOCOUNT ON

	DECLARE @transInfo	XML
			,@IsSiteDB	BIT = 0
	
	IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
	SET @IsSiteDB = 1

	DECLARE @tmpTransInfo TABLE (
			Action VARCHAR(1)
			,transId BIGINT
			,bef_winlost MONEY 
			,bef_statusid TINYINT
			,custid	INT
			,transdate	DATETIME
			,oddsid	INT
			,hdp1	SMALLMONEY
			,hdp2	SMALLMONEY
			,odds	SMALLMONEY
			,stake	MONEY
			,[status]	NVARCHAR(20)
			,winlost	MONEY
			,awinlost	MONEY
			,mwinlost	MONEY
			,playercomm	MONEY
			,comm	MONEY
			,acomm	MONEY
			,apositiontaking	SMALLMONEY
			,mpositiontaking	SMALLMONEY
			,tpositiontaking	SMALLMONEY
			,playerdiscount	DECIMAL
			,discount	DECIMAL
			,adiscount	DECIMAL
			,livehomescore	SMALLINT
			,liveawayscore	SMALLINT
			,liveindicator	BIT
			,betteam	NVARCHAR(20)
			,creator	INT
			,refno	BIGINT
			,comstatus	NVARCHAR(40)
			,winlostdate	SMALLDATETIME
			,betfrom	NVARCHAR(3)
			,betcheck	NVARCHAR(100)
			,checktime	DATETIME
			,oddsspread	MONEY
			,actualrate	FLOAT
			,matchid	INT
			,recommend	INT
			,mrecommend	INT
			,ruben	TINYINT
			,betid	BIGINT
			,statuswinlost	TINYINT
			,modds	SMALLMONEY
			,bettype	SMALLINT
			,betdaqid	BIGINT
			,actual_stake	MONEY
			,currency	TINYINT
			,[ip]	VARCHAR(45)
			,transdesc	NVARCHAR(2000)
			,sdiscount	DECIMAL
			,scomm	MONEY
			,spositiontaking	SMALLMONEY
			,swinlost	MONEY
			,srecommend	INT
			,Username	NVARCHAR(100)
			,CurrencyName	NVARCHAR(100)
			,virtualrate	FLOAT
			,oddstype	TINYINT
			,statusID	TINYINT
			,currency2	TINYINT
			,balance	MONEY
			,SecAcceptFlag	BIT
			,transid2	BIGINT
			,RecommDate	DATETIME
			,SiteDBGroupID	SMALLINT
			)
		
	IF @Action IN ('CAL', 'CAL-FT', 'VOID')
	BEGIN
		--for case void & recover
		IF ISNULL(@CustIds, '') <> ''
		BEGIN
			DECLARE @CustIdList TABLE(CustId INT)
			INSERT INTO @CustIdList(CustId)
			SELECT CAST([value] AS INT)
			FROM STRING_SPLIT(@CustIds, ',')
		END

		CREATE TABLE #NetWinCust (FirstTransId		BIGINT PRIMARY KEY
									,NetWin			MONEY
									,CustId			INT
									,PlayerDiscount DECIMAL(9,8)
									,Discount		DECIMAL(9,8)
									,ADiscount		DECIMAL(9,8)
									,Creator		INT
									,WinlostDate	SMALLDATETIME
									,BetFrom		NVARCHAR(3)
									,BetCheck		NVARCHAR(50)
									,ActualRate		FLOAT
									,Recommend		INT
									,MRecommend		INT
									,Currency		TINYINT
									,SDiscount		DECIMAL(9,8)
									,SRecommend		INT
									,Username		NVARCHAR(50)
									,CurrencyName	NVARCHAR(50)
									,VirtualRate	FLOAT
									,SiteDBGroupID	SMALLINT
								)
									
		INSERT INTO #NetWinCust (FirstTransId, NetWin, CustId, SiteDBGroupID)
		SELECT	MIN(transid), SUM(winlost - actual_stake), custid, b.SiteDBGroupID
		FROM	dbo.bettrans b WITH(NOLOCK)
		WHERE	matchid = @matchid
				AND bettype = 501
				AND (ISNULL(@CustIds, '') = '' OR (ISNULL(@CustIds, '') <> '' AND EXISTS (SELECT 1 FROM @CustIdList s WHERE b.CustId = s.CustId)))
				AND statusID NOT IN (0, 1, 101, 102) -- REJECT, VOID
				AND playerdiscount < 0
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END
		GROUP BY b.custid, b.SiteDBGroupID
		
		UPDATE	n
			SET PlayerDiscount = b.playerdiscount
				,Discount = b.discount
				,ADiscount = b.adiscount
				,Creator = b.creator
				,WinlostDate = b.winlostdate
				,BetFrom = b.betfrom
				,BetCheck = b.betcheck
				,ActualRate = b.actualrate
				,Recommend = b.recommend
				,MRecommend = b.mrecommend
				,Currency = b.currency
				,SDiscount = b.sdiscount
				,SRecommend = b.srecommend
				,Username = b.Username
				,CurrencyName = b.CurrencyName
				,VirtualRate = b.virtualrate					
		FROM #NetWinCust n
			INNER JOIN dbo.bettrans b WITH(NOLOCK)
				ON n.FirstTransId = b.transid
		
		IF EXISTS (SELECT TOP 1 1 FROM #NetWinCust)
		BEGIN
			MERGE	dbo.bettrans AS b
			USING	(SELECT * FROM #NetWinCust) AS n
				ON	b.matchid = @MatchId
					AND b.bettype = 500
					AND b.custid = n.CustId
			WHEN MATCHED AND b.winlost <> n.NetWin 
				AND b.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN b.SiteDBGroupID ELSE 0 END
								THEN UPDATE SET	[status] = CASE WHEN n.NetWin > 0 THEN 'LOSE' ELSE 'VOID' END
																	,winlost = CASE WHEN n.NetWin > 0 THEN n.NetWin ELSE 0 END
																	,playerdiscount = n.PlayerDiscount
																	,discount = n.Discount
																	,adiscount = n.ADiscount
																	,sdiscount = n.SDiscount
																	,playercomm = CASE WHEN n.NetWin > 0 THEN n.PlayerDiscount * n.NetWin ELSE 0 END
																	,comm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.Discount) * n.NetWin ELSE 0 END
																	,acomm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.ADiscount) * n.NetWin ELSE 0 END
																	,scomm = CASE WHEN n.NetWin > 0 THEN (n.PlayerDiscount - n.SDiscount) * n.NetWin ELSE 0 END														
																	,actual_stake = CASE WHEN n.NetWin > 0 THEN n.NetWin ELSE 0 END
																	,statusID = CASE WHEN n.NetWin > 0 THEN 113 ELSE 102 END
																	,statuswinlost = CASE WHEN n.NetWin > 0 THEN NULL ELSE 6 END

			WHEN NOT MATCHED BY TARGET AND n.NetWin > 0 AND n.SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN n.SiteDBGroupID ELSE 0 END
										THEN INSERT (	
													custid
													,transdate
													,oddsid
													,hdp1
													,hdp2
													,odds
													,stake
													,[STATUS]
													,winlost
													,awinlost
													,mwinlost
													,playercomm
													,comm
													,acomm
													,apositiontaking
													,mpositiontaking
													,tpositiontaking
													,playerdiscount
													,discount
													,adiscount
													,livehomescore
													,liveawayscore
													,liveindicator
													,betteam
													,creator
													,refno
													,comstatus
													,winlostdate
													,betfrom
													,betcheck
													,checktime
													,oddsspread
													,actualrate
													,matchid
													,recommend
													,mrecommend
													,ruben
													,betid
													,statuswinlost
													,modds
													,bettype
													,betdaqid						
													,actual_stake
													,currency
													,ip
													,transdesc
													,sdiscount
													,scomm
													,spositiontaking
													,swinlost
													,srecommend
													,Username
													,CurrencyName
													,virtualrate
													,oddstype
													,statusID
													,currency2
													,balance
													,SecAcceptFlag
													,transid2
													,RecommDate
													,SiteDBGroupID
												)
										VALUES (custid
												,GETDATE() --AS transdate
												,0 --AS oddsid
												,0 --AS hdp1
												,0 --AS hdp2
												,0 --AS odds
												,0 --AS stake
												,'LOSE' --AS [STATUS]
												,n.NetWin --AS winlost
												,0 --AS awinlost
												,0 --AS mwinlost
												,n.PlayerDiscount * n.NetWin --AS playercomm
												,(n.PlayerDiscount - n.Discount) * n.NetWin --AS comm
												,(n.PlayerDiscount - n.ADiscount) * n.NetWin --AS acomm
												,0 --AS apositiontaking
												,0 --AS mpositiontaking
												,0 --AS tpositiontaking
												,n.PlayerDiscount
												,n.Discount
												,n.ADiscount
												,0 --AS livehomescore
												,0 --AS liveawayscore
												,0 --AS liveindicator
												,NULL --AS betteam
												,n.Creator
												,100000000000 --AS refno
												,NULL --AS comstatus
												,n.WinlostDate
												,n.BetFrom
												,n.BetCheck
												,NULL --AS checktime
												,NULL --AS oddsspread
												,n.ActualRate
												,@Matchid
												,n.Recommend
												,n.MRecommend
												,1 --AS ruben
												,NULL --AS betid
												,NULL --AS statuswinlost
												,-1 --AS modds
												,500 --AS bettype
												,NULL --AS betdaqid
												,n.NetWin --AS actual_stake
												,n.Currency
												,'' --AS ip
												,'' --AS transdesc
												,n.SDiscount
												,(n.PlayerDiscount - n.SDiscount) * n.NetWin --AS scomm
												,0 --AS spositiontaking
												,0 --AS swinlost
												,n.SRecommend
												,n.Username
												,n.CurrencyName
												,n.VirtualRate
												,NULL --AS oddstype
												,113 --AS statusID
												,NULL --AS currency2
												,NULL --AS balance
												,NULL --AS SecAcceptFlag
												,NULL --AS transid2
												,NULL --AS RecommDate
												,SiteDBGroupID
												)
				OUTPUT CASE WHEN ISNULL(deleted.transId,0) = 0 THEN 'I' ELSE 'U' END AS [Action]
						,inserted.transId	
						,deleted.winlost AS bef_winlost 
						,deleted.statusid  AS bef_statusid  
						,inserted.custid 
						,inserted.transdate	 
						,inserted.oddsid	 
						,inserted.hdp1	 
						,inserted.hdp2	 
						,inserted.odds	 
						,inserted.stake	 
						,inserted.[status] 
						,inserted.winlost 
						,inserted.awinlost 
						,inserted.mwinlost 
						,inserted.playercomm	 
						,inserted.comm	 
						,inserted.acomm	 
						,inserted.apositiontaking 
						,inserted.mpositiontaking 
						,inserted.tpositiontaking 
						,inserted.playerdiscount 
						,inserted.discount	 
						,inserted.adiscount	 
						,inserted.livehomescore	 
						,inserted.liveawayscore	 
						,inserted.liveindicator	 
						,inserted.betteam 
						,inserted.creator 
						,inserted.refno	 
						,inserted.comstatus	 
						,inserted.winlostdate	 
						,inserted.betfrom	 
						,inserted.betcheck	 
						,'' AS checktime	 
						,'' AS oddsspread	 
						,inserted.actualrate	 
						,inserted.matchid	 
						,inserted.recommend	 
						,inserted.mrecommend	 
						,inserted.ruben	 
						,'' AS betid	 
						,'' AS statuswinlost	 
						,inserted.modds	 
						,inserted.bettype	 
						,'' AS betdaqid	 
						,inserted.actual_stake	 
						,inserted.currency	 
						,inserted.[ip]	 
						,inserted.transdesc	 
						,inserted.sdiscount	 
						,inserted.scomm	 
						,inserted.spositiontaking 
						,inserted.swinlost	 
						,inserted.srecommend	 
						,inserted.Username	 
						,inserted.CurrencyName	 
						,inserted.virtualrate	 
						,'' AS oddstype	 
						,inserted.statusID	 
						,'' AS currency2	 
						,'' AS balance	 
						,'' AS SecAcceptFlag	 
						,'' AS transid2	 
						,'' AS RecommDate
						,inserted.SiteDBGroupID	 
			INTO @tmpTransInfo (
						[Action]
						,transId	
						,bef_winlost 
						,bef_statusid  
						,custid 
						,transdate	 
						,oddsid	 
						,hdp1	 
						,hdp2	 
						,odds	 
						,stake	 
						,[status] 
						,winlost 
						,awinlost 
						,mwinlost 
						,playercomm	 
						,comm	 
						,acomm	 
						,apositiontaking 
						,mpositiontaking 
						,tpositiontaking 
						,playerdiscount 
						,discount	 
						,adiscount	 
						,livehomescore	 
						,liveawayscore	 
						,liveindicator	 
						,betteam 
						,creator 
						,refno	 
						,comstatus	 
						,winlostdate	 
						,betfrom	 
						,betcheck	 
						,checktime	 
						,oddsspread	 
						,actualrate	 
						,matchid	 
						,recommend	 
						,mrecommend	 
						,ruben	 
						,betid	 
						,statuswinlost	 
						,modds	 
						,bettype	 
						,betdaqid	 
						,actual_stake	 
						,currency	 
						,[ip]	 
						,transdesc	 
						,sdiscount	 
						,scomm	 
						,spositiontaking 
						,swinlost	 
						,srecommend	 
						,Username	 
						,CurrencyName	 
						,virtualrate	 
						,oddstype	 
						,statusID	 
						,currency2	 
						,balance	 
						,SecAcceptFlag	 
						,transid2	 
						,RecommDate	 
						,SiteDBGroupID	 
						);
		
			IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo WHERE Action = 'U')
			BEGIN
				SELECT @transInfo = (
					SELECT  transid AS '@t'
							,[status]  AS '@s'
							,winlost AS '@w'
							,playerdiscount  AS '@pd'
							,discount  AS '@d'
							,adiscount  AS '@ad'
							,sdiscount  AS '@sd'
							,playercomm  AS '@pc'
							,comm   AS '@c'
							,acomm  AS '@ac'
							,scomm 	 AS '@sc'												
							,actual_stake  AS '@as'
							,statusID  AS '@sid'
							,statuswinlost  AS '@statuswl'
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
					FROM @tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateCommission', 'bettrans', @MatchId, @transInfo)	
			END

			IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo WHERE Action = 'I')
			BEGIN
				SELECT @transInfo = (
				SELECT  transid		AS '@t'
						,custid		AS '@cust'
						,transdate	AS '@td'
						,oddsid		AS '@oid'
						,hdp1		AS '@hdp1'
						,hdp2		AS '@hdp2'
						,odds		AS '@o'
						,stake		AS '@stake'
						,[STATUS]	AS '@s'
						,winlost	AS '@w'
						,awinlost	AS '@aw'
						,mwinlost	AS '@mw'
						,playercomm AS '@pc'
						,comm		AS '@c'
						,acomm		AS '@ac'
						,apositiontaking AS '@apos'	
						,mpositiontaking AS '@mpos'
						,tpositiontaking AS '@tpos'
						,playerdiscount	 AS '@pd'
						,discount		AS '@d'
						,adiscount		AS '@ad'
						,livehomescore	AS '@lh'
						,liveawayscore	AS '@la'
						,liveindicator	AS '@li'
						,betteam		AS '@bteam'
						,creator		AS '@cr'
						,refno			AS '@ref'
						,comstatus		AS '@cst'
						,winlostdate	AS '@wld'
						,betfrom		AS '@bf'
						,betcheck		AS '@bc'
						,checktime		AS '@ct'
						,oddsspread		AS '@os'
						,actualrate		AS '@ar'
						,matchid		AS '@mid'
						,recommend		AS '@rc'
						,mrecommend		AS '@mrc'
						,ruben			AS '@r'
						,betid			AS '@bid'
						,statuswinlost	AS '@statuswl'
						,modds			AS '@m'
						,bettype		AS '@btype'
						,betdaqid		AS '@bdq'				
						,actual_stake	AS '@astake'
						,currency		AS '@cur'
						,ip				AS '@ip'
						,transdesc		AS '@tdesc'
						,sdiscount		AS '@sdis'
						,scomm			AS '@sc'
						,spositiontaking AS '@spos'
						,swinlost		AS '@sw'
						,srecommend		AS '@src'
						,Username		AS '@uname'
						,CurrencyName	AS '@curname'
						,virtualrate	AS '@v'
						,oddstype		AS '@otype'
						,statusID		AS '@sid'
						,currency2		AS '@cur2'
						,balance		AS '@b'
						,SecAcceptFlag	AS '@sec'
						,transid2		AS '@t2'
						,RecommDate		AS '@rcd'
						,SiteDBGroupID	AS '@sgid'
				FROM @tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo, [Action])
				VALUES ('Settlement', 'CalculateCommission', 'bettrans', @MatchId, @transInfo, 'I')
			END
		END
		ELSE IF ISNULL(@CustIds, '') <> ''
		BEGIN
			--for case all of tickets [501] has been voided. So we no need to re-calculate charge comm
			UPDATE dbo.bettrans WITH(ROWLOCK, UPDLOCK)
			SET	[status] = 'VOID'
				,winlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,actual_stake = 0
				,statusID = 102
				,statuswinlost = 6
			WHERE matchid = @MatchId
				AND bettype = 500
				AND custid IN (SELECT CustId FROM @CustIdList)
				AND statusID NOT IN (101, 102) -- REJECT, VOID
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END

			IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SELECT @transInfo = (
					SELECT  transid AS '@t'
							,[status]  AS '@s'
							,winlost AS '@w'
							,playerdiscount  AS '@pd'
							,comm   AS '@c'
							,acomm  AS '@ac'
							,scomm 	 AS '@sc'												
							,actual_stake  AS '@as'
							,statusID  AS '@sid'
							,statuswinlost  AS '@statuswl'
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
					FROM @tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateCommission', 'bettrans', @MatchId, @transInfo)
			END	
		END
		
		DROP TABLE #NetWinCust
	END
	ELSE IF @Action IN ('REFUND', 'REFUND-FT', 'UNDO')
	BEGIN
		UPDATE	dbo.bettrans WITH(ROWLOCK, UPDLOCK)
			SET	[status] = 'VOID'
				,winlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
				,actual_stake = 0
				,statusID = 102
				,statuswinlost = 6
		WHERE	matchid = @MatchId
				AND bettype = 500
				AND statusID NOT IN (101, 102) -- REJECT, VOID
				AND SiteDBGroupID = CASE WHEN @IsSiteDB = 1 THEN SiteDBGroupID ELSE 0 END

		IF @IsSiteDB = 1 AND EXISTS(SELECT TOP 1 1 FROM @tmpTransInfo)
			BEGIN
				SELECT @transInfo = (
					SELECT  transid AS '@t'
							,[status]  AS '@s'
							,winlost AS '@w'
							,playerdiscount  AS '@pd'
							,comm   AS '@c'
							,acomm  AS '@ac'
							,scomm 	 AS '@sc'												
							,actual_stake  AS '@as'
							,statusID  AS '@sid'
							,statuswinlost  AS '@statuswl'
							,bef_winlost AS '@bef_w' 
							,bef_statusid AS '@bef_sid' 
					FROM @tmpTransInfo
				FOR XML PATH('r'),ROOT('root'), TYPE
				)
				INSERT INTO dbo.SiteDB_SettlementService_CalculationLog (SystemName, FunctionName, TableName, MatchId, TransInfo)
				VALUES ('Settlement', 'CalculateCommission', 'bettrans', @MatchId, @transInfo)
			END	
				
	END
END
GO