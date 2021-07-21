/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_01] 	
	@transIds		   VARCHAR(MAX) = ''
	,@IsMarked			BIT = 0
	,@fth							INT = 0
	,@fta							INT = 0
	,@hth INT = 0
	,@hta INT = 0
AS
/*
	Created by: 20210730@Kathy
	Task: Settlement  
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20210730@Kathy: Apply Settlement by Profile for minor bettype of soccer [Redmine:#158477]
		
	Param's Explanation:  
		   
		@transIds = '<root>
						<r t="104730774034" m="1"/>
						<r t="104729373985" m="0" ot="1"/>
					</root>'
					t:  transid
					m:  modds
					ot: oddstype: 1: DECIMAL ONLY
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT

	SET @ServerName = @@SERVERNAME

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END

	DECLARE @modds				MONEY
		,@commWinRate			SMALLMONEY
		,@commLostRate			SMALLMONEY

		,@BatchNo				INT = 2000
		,@statusId				TINYINT
		,@winlost				MONEY
		,@totalWinScore			VARCHAR(10)
		,@tmpTotalWinScore		VARCHAR(10)
		,@totalLiveWinScore		SMALLINT
		,@odds					MONEY
		,@posOdds				INT
		,@posComma				INT
		,@settlementTime		DATETIME
		,@IsUpd_Void			BIT = 0
		,@xml					XML
	
	DECLARE @tmpTrans TABLE (TransID BIGINT PRIMARY KEY)
	
	SET @xml = CAST(@transIds AS XML)

	INSERT INTO @tmpTrans (TransID)
	SELECT T.C.value('./@t', 'bigint') AS transid
	FROM @xml.nodes('/root/r') AS T(C)
	OPTION (OPTIMIZE FOR (@xml = NULL ))
				
	SET @settlementTime = GETDATE();

	UPDATE TOP (@BatchNo) b
		SET @totalWinScore = CASE WHEN b.bettype = 468 THEN @fth - @fta
						WHEN b.bettype = 469 THEN @fth + @fta
					ELSE NULL
				END					
			,@totalLiveWinScore = CASE WHEN b.bettype = 468 THEN CAST(@totalWinScore AS SMALLINT) - (b.livehomescore - b.liveawayscore) ELSE CAST(@totalWinScore AS SMALLINT) END
			,@tmpTotalWinScore = CAST(CAST(CASE WHEN @totalLiveWinScore  > b.hdp1 THEN b.hdp1
												WHEN @totalLiveWinScore < b.hdp1 - b.hdp2 + 1 THEN b.hdp1 - b.hdp2 + 1
												ELSE @totalLiveWinScore
									END AS INT)
								AS VARCHAR(10))
			,@posOdds = CHARINDEX(@tmpTotalWinScore + ':', b.betcheck) + LEN(@tmpTotalWinScore) + 1
			,@posComma = CHARINDEX(',', b.betcheck + ',', @posOdds)
			,@odds = SUBSTRING(b.betcheck, @posOdds, @posComma - @posOdds)
			,@modds = CASE WHEN @odds > 0 THEN 1
							WHEN @odds < 0 THEN -1 
							WHEN @odds = 0 THEN 0
							ELSE -1
						END
			,statuswinlost = CASE WHEN @modds > 0.25 THEN 2
								WHEN @modds = 0.25 THEN 1 
								WHEN @modds = 0 THEN 0 
								WHEN @modds = - 0.25 THEN 3
								WHEN @modds < - 0.25 THEN 4
								WHEN @modds IS NULL THEN 6
							END
			,@IsUpd_Void = CASE WHEN (statusID = 102) OR (@IsMarked = 1) THEN 0 ELSE 1 END
			,modds = @modds
			-- update odds, oddsspread
			,odds = @odds
			,oddsspread = @tmpTotalWinScore
			,@commWinRate = CASE comstatus -- 0 : pay normal, both win/lost -- 1 : pay 'double' ONLY on lost
				WHEN '0' THEN 1
				WHEN '1' THEN 0
				ELSE 1
				END
			,@commLostRate = CASE comstatus
				WHEN '0' THEN 1
				WHEN '1' THEN 2
				ELSE 1
				END
			-- check winlost or status change to update SettlementTime
			,@statusId = CASE 
							WHEN @modds > 0 THEN 112 --WON
							WHEN @modds < 0 THEN 113 --LOSE
							WHEN @modds = 0 THEN 111 --Draw
						END
			,@winlost = CASE 
							WHEN @modds > 0 THEN actual_stake + stake * @odds
							WHEN @modds = 0 THEN actual_stake
							WHEN @modds < 0 THEN actual_stake + stake * @odds
						END
			,SettlementTime = CASE 
									WHEN @IsUpd_Void = 0 THEN SettlementTime 
									ELSE CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
								END
								
			,WinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN WinLost 
							ELSE @winlost
						END
			,aWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN aWinLost 
							ELSE CASE 
									WHEN @modds > 0 THEN stake * @odds * - apositiontaking
									WHEN @modds = 0 THEN 0
									WHEN @modds < 0 THEN stake * @odds * - apositiontaking
								END
						END
										
			,mWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN mWinLost 
							ELSE CASE 
									WHEN @modds > 0 THEN stake * @odds * - mpositiontaking
									WHEN @modds = 0 THEN 0
									WHEN @modds < 0 THEN stake * @odds * - mpositiontaking
								END
						END
								
			,sWinLost = CASE 
							WHEN @IsUpd_Void = 0 THEN sWinLost 
							ELSE CASE 
									WHEN @modds > 0 THEN stake * @odds * - spositiontaking
									WHEN @modds = 0 THEN 0
									WHEN @modds < 0 THEN stake * @odds * - spositiontaking
								END
						END
								
			,PlayerComm = CASE 
							WHEN @IsUpd_Void = 0 THEN PlayerComm 
							ELSE CASE 
									WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
									WHEN @modds = 0 THEN 0
									WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
								END
						END
								
			,Comm = CASE 
						WHEN @IsUpd_Void = 0 THEN Comm 
						ELSE CASE 
								WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
							END
						END
								
			,aComm = CASE 
						WHEN @IsUpd_Void = 0 THEN aComm 
						ELSE CASE 
								WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
							END
						END
								
			,sComm = CASE 
						WHEN @IsUpd_Void = 0 THEN sComm 
						ELSE CASE 
								WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
								WHEN @modds = 0 THEN 0
								WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
							END
						END
								
			,STATUS = CASE 
						WHEN @IsUpd_Void = 0 THEN [status] 
						ELSE CASE 
								WHEN @modds > 0 THEN 'WON'
								WHEN @modds < 0 THEN 'LOSE'
								WHEN @modds = 0 THEN 'DRAW'
							END
						END
								
			,StatusID = CASE 
							WHEN @IsUpd_Void = 0 THEN StatusID 
							ELSE @statusId
						END
								
			,ruben = CASE 
							WHEN @IsUpd_Void = 0 THEN ruben 
							ELSE 1
						END
								
	FROM @tmpTrans sr
		INNER JOIN dbo.bettrans b  WITH (ROWLOCK, UPDLOCK) ON  sr.transid = b.transid
	OPTION (OPTIMIZE FOR (@batchNo = 1))
END
GO
