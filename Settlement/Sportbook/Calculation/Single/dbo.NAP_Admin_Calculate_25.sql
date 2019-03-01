/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_25_UAT1] @matchid INT
	,@bettype SMALLINT
	,@scorediff SMALLMONEY
	,@betcount INT = 0
AS
/*
	Created by: Kathy
	Date:20140211
	Task: Settlement 
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20150415@Jamie: Settlement Betradar phase 2 [Redmine: #27212]
		- 20151125@Patrick: Apply 28 Live Bettypes for Settlement [Redmine:#47843]
		- 20151209@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160705@Kathy: PH-AIO phase 2 (67 bettypes ) [Redmine:#53154]
		- 20180704@Helen: Prevent lock escalation on Bettrans [Redmine:#89132]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190227@Sol:  New Formula for Comm [Redmine:#109007]

*/
BEGIN
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
	DECLARE @ServerName			SYSNAME 
			,@AllowCalculation	BIT

	SET @ServerName = @@SERVERNAME

    IF @betcount = 0 AND @ServerName NOT LIKE N'DBIOM%' RETURN

	IF OBJECT_ID('NAP_Set_ServerAction', 'P') IS NOT NULL
	BEGIN
		EXEC [dbo].[NAP_Set_ServerAction]
			@ServerName			= @ServerName
			,@AllowCalculation	= @AllowCalculation	OUTPUT

		IF @AllowCalculation = 0
			RETURN
	END
	-- END CHECK

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
		,@winlost				MONEY
		,@stake					MONEY
		,@commBettypeGroupId	SMALLINT

	 DECLARE 
		 @BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT

	DECLARE @tmpBatch AS TABLE (
		BatchNo					INT
		,CustId					INT
		,sRecommend				INT
		,IsCN88					BIT
		,MinCustId				INT
		,MaxCustId				INT
		,MinTransId				BIGINT
		,MaxTransId				BIGINT
		,TransIdOfMinCust		BIGINT
		,TransIdOfMaxCust		BIGINT
		,UNIQUE CLUSTERED (BatchNo, CustId)
	)
		
	SET	@BatchCount = 2000

	INSERT INTO @tmpBatch (BatchNo, CustId, sRecommend, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
	SELECT	BatchNo
			,custid
			,sRecommend
			,MAX(CASE WHEN MinRn = 0 THEN CustId ELSE 0 END) AS MinCustId
			,MAX(CASE WHEN MaxRn = 1 THEN CustId ELSE 0 END) AS MaxCustId
			,MAX(CASE WHEN TransIdAsc = 1 THEN transId ELSE 0 END ) AS MinTransId	
			,MAX(CASE WHEN TransIdDesc = 1 THEN transId ELSE 0 END ) AS MaxTransId			
			,MAX(CASE WHEN MinRn = 0 THEN transid ELSE 0 END) AS TransIdOfMinCust
			,MAX(CASE WHEN MaxRn = 1 THEN transid ELSE 0 END) AS TransIdOfMaxCust
	FROM (
		SELECT	n.BatchNo
				,b.custid
				,b.transid
				,b.sRecommend
				,(rn - 1)%@BatchCount AS MinRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
		FROM	(
			SELECT	transid
					,custid
					,sRecommend
					,ROW_NUMBER() OVER (ORDER BY custid, transid) AS rn
			FROM	dbo.bettrans WITH(NOLOCK)
			WHERE	matchid = @matchid
					AND bettype = @bettype
		)b
		CROSS APPLY (	
			SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
		)n
	)b
	GROUP BY BatchNo, CustId, sRecommend

	-- update if bettype belongs to the CN88 site or not
	UPDATE tmp
	  SET  isCN88 = CASE WHEN cs.CustId IS NULL THEN 0 ELSE 1 END
	FROM   @tmpBatch tmp
			   LEFT JOIN dbo.CS_CustSuper cs WITH(NOLOCK)
				   ON tmp.srecommend = cs.CustId;

	-- get CommBettypeGroupId 
	SELECT @commBettypeGroupId = CommBettypeGroupId FROM dbo.f_Set_GetGroupBettypes_UAT1() AS f WHERE BetType = @bettype
				
	SELECT @BatchNo = MAX(BatchNo)
	FROM @tmpBatch
		
	WHILE @BatchNo > 0
	BEGIN
		SELECT	@MinCustId = MAX(MinCustId)
				,@MaxCustId = MAX(MaxCustId)
				,@MinTransId = MAX(MinTransId)
				,@MaxTransId = MAX(MaxTransId)
				,@TransIdOfMinCust = MAX(TransIdOfMinCust)
				,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
		FROM	@tmpBatch
		WHERE	BatchNo = @BatchNo
			
		UPDATE b
		SET @modds = CASE 
				-- draw no bet
				WHEN bettype IN (25,185,191,411,432) AND @scorediff = 0 THEN 0
				WHEN bettype IN (25,185,191,411,432) AND betteam = 'h' AND @scorediff > 0 THEN 1
				WHEN bettype IN (25,185,191,411,432) AND betteam = 'a' AND @scorediff < 0 THEN 1
					-- home no bet
				WHEN bettype = 121 AND @scorediff > 0 THEN 0
				WHEN bettype = 121 AND betteam = 'x' AND @scorediff = 0 THEN 1
				WHEN bettype = 121 AND betteam = 'a' AND @scorediff < 0 THEN 1
					-- away no bet
				WHEN bettype = 122 AND @scorediff < 0 THEN 0
				WHEN bettype = 122 AND betteam = 'h' AND @scorediff > 0 THEN 1
				WHEN bettype = 122 AND betteam = 'x' AND @scorediff = 0 THEN 1
					-- draw/no draw		
				WHEN bettype = 123 AND betteam = 'h' AND @scorediff = 0 THEN 1
				WHEN bettype = 123 AND betteam = 'a' AND @scorediff <> 0 THEN 1
				ELSE - 1
				END
			,modds = @modds
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
			,@winlost = CASE 
				WHEN @modds > 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						)
				WHEN @modds = 0.25 THEN actual_stake + stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * 0.5
				WHEN @modds = 0 THEN actual_stake
				WHEN @modds = - 0.25 THEN actual_stake * 0.5
				WHEN @modds < - 0.25 THEN 0
				END
			-- check if bettype belongs to major comm group (CommBettypeGroupId = 1) and calc comm with new formula
			,@stake = CASE WHEN c.IsCN88 = 1 AND @commBettypeGroupId = 1 THEN ABS(@winlost - actual_stake)
						ELSE stake 
					END 
			,WinLost = @winlost
			,aWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - apositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * apositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * apositiontaking
				END
			,mWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - mpositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * mpositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * mpositiontaking
				END
			,sWinLost = CASE 
				WHEN @modds > 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking
				WHEN @modds = 0.25 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE (CASE 
								WHEN bettype IN (4, 5, 6, 13, 15, 16, 24, 25, 26, 27, 28, 121, 122, 123,185,191,411,432) THEN odds - 1
								ELSE odds END
								) END
						) * - spositiontaking * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN actual_stake * spositiontaking * 0.5
				WHEN @modds < - 0.25 THEN actual_stake * spositiontaking
				END
			,PlayerComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * playerdiscount * @stake
				WHEN @modds = 0.25 THEN @commWinRate * playerdiscount * @stake * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * playerdiscount * @stake * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * playerdiscount * @stake
				END
			,Comm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking)
				WHEN @modds = 0.25 THEN @commWinRate * discount * @stake * (1 - apositiontaking) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * discount * @stake * (1 - apositiontaking)
				END
			,aComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * adiscount * @stake * (1 - (mpositiontaking + apositiontaking))
				END
			,sComm = CASE 
				WHEN @modds > 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				WHEN @modds = 0.25 THEN @commWinRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds = 0 THEN 0
				WHEN @modds = - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking)) * 0.5
				WHEN @modds < - 0.25 THEN @commLostRate * sdiscount * @stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
				END
			,STATUS = CASE 
				WHEN @modds > 0 THEN 'WON'
				WHEN @modds = 0 THEN 'DRAW'
				WHEN @modds < 0 THEN 'LOSE'
				END
			,StatusID = CASE 
				WHEN @modds > 0 THEN 112 --WON
				WHEN @modds = 0 THEN 111 --DRAW
				WHEN @modds < 0 THEN 113 --LOSE
				END
			,ruben = 1
		FROM	@tmpBatch c
					INNER JOIN dbo.bettrans b
						ON	c.BatchNo = @BatchNo
							AND c.CustId = b.custid
					CROSS APPLY (
						SELECT CASE
									WHEN c.CustId = @MinCustId AND transId < @TransIdOfMinCust THEN 0
									WHEN c.CustId = @MaxCustId AND transId > @TransIdOfMaxCust THEN 0
									WHEN b.transId BETWEEN @MinTransId AND @MaxTransId THEN 1 
									ELSE 0
								END AS IsCalculated
					)i	
		WHERE matchid = @matchid AND bettype = @bettype 
			AND	statusID NOT IN (101, 102) --status NOT IN ('VOID', 'REJECT')
			AND i.IsCalculated = 1
				
		SET @BatchNo = @BatchNo - 1

		WAITFOR DELAY '00:00:00:010'
					
	END	
		
END
GO