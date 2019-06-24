/*<info serverAlias="DBTXN-bodb02" executers="" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_135] @matchid INT
	,@bettype						SMALLINT
	,@ResourceIDs					VARCHAR(MAX)	= NULL
	,@result						NVARCHAR(MAX)   = ''
	,@IsReSettledTickets			BIT	= 1
	-- add any params, please modify script in 'special section'
AS
/*
	Created by: Kathy
	Date:20140211
	Task: Settlement for Penalty Shootout [Redmine:#17142]
	DB: DBTRANS.BODB02
	
	Revisions:
		- 20140825@Kathy: correct @result in LasCommand
		- 20150206@Jamie: Auto Settlement Betradar phase 2 [Redmine: #27212]
		- 20150618@Jamie: Offer the option Exclude Corner tickets [Feature #38099]
		- 20151208@Patrick: Database - Change datatype [Redmine: #48660]
		- 20160830@Kathy: PH-AIO phase 2b [Redmine:#62861]
		- 20171023@Helen: PHAIO 3 - Integrate into Settlement site [Redmine:#80947]
		- 20180904@Kathy: Change CIX on DB054 [Redmine:#100828]
		- 20181004@Kathy: Change CIX on DB053 [Redmine:#102594]
		- 20181030@Kathy: Change CIX on DB052 [Redmine:#103985]
		- 20181129@Kathy: Do not settle ticket on DB04x [Redmine:#105327]
		- 20190320@Kathy: Settlement with Tickets Exclusion [Redmine:#106823]
		- 20190408@Sol: Settlement Time [Redmine:#99638]
		- 20190620@Kathy: Remove auto betradar, corner bettypes [Redmine:#109584]
*/
BEGIN 
	SET NOCOUNT ON

	-- CHECK SERVER BEFORE CALCULATING
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
	-- END CHECK

	DECLARE @modds MONEY
		,@commWinRate SMALLMONEY
		,@commLostRate SMALLMONEY
		,@RemoteCount INT
		,@bettype_22 VARCHAR(20)
		,@bettype_160 VARCHAR(20)

		,@BatchCount			INT
		,@BatchNo				INT
		,@MinCustId				INT
		,@MaxCustId				INT
		,@MinTransId			BIGINT
		,@MaxTransId			BIGINT
		,@TransIdOfMinCust		BIGINT
		,@TransIdOfMaxCust		BIGINT
		,@winlost				MONEY
		,@statusId				TINYINT
    
    SET @bettype_22 = '22'
    SET @bettype_160 = '160'	

	DECLARE @tmpBatch AS TABLE (
		BatchNo					INT
		,CustId					INT
		,MinCustId				INT
		,MaxCustId				INT
		,MinTransId				BIGINT
		,MaxTransId				BIGINT
		,TransIdOfMinCust		BIGINT
		,TransIdOfMaxCust		BIGINT
		,UNIQUE CLUSTERED (BatchNo, CustId)
	)

	SET	@BatchCount = 2000

	DECLARE @settlementTime DATETIME
	
	INSERT INTO @tmpBatch (BatchNo, CustId, MinCustId, MaxCustId, MinTransId, MaxTransId, TransIdOfMinCust, TransIdOfMaxCust)
	SELECT	BatchNo
			,custid
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
				,(rn - 1)%@BatchCount AS MinRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY b.rn DESC) MaxRn
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid DESC) TransIdDesc
				,ROW_NUMBER() OVER (PARTITION BY n.BatchNo ORDER BY transid) TransIdAsc
		FROM	(
			SELECT	transid
					,custid
					,ROW_NUMBER() OVER (ORDER BY custid, transid) AS rn
			FROM	dbo.bettrans WITH(NOLOCK)
			WHERE	matchid = @matchid
					AND bettype = @bettype
					AND statusID = CASE WHEN @IsReSettledTickets = 0 THEN 0 ELSE statusID END
		)b
		CROSS APPLY (	
			SELECT	((b.rn - 1) /@BatchCount) + 1 AS BatchNo
		)n
	)b
	GROUP BY BatchNo, CustId
			
	SELECT @BatchNo = MAX(BatchNo)
	FROM @tmpBatch

	WHILE (@BatchNo > 0)
	BEGIN	
		SELECT	@MinCustId = MAX(MinCustId)
				,@MaxCustId = MAX(MaxCustId)
				,@MinTransId = MAX(MinTransId)
				,@MaxTransId = MAX(MaxTransId)
				,@TransIdOfMinCust = MAX(TransIdOfMinCust)
				,@TransIdOfMaxCust = MAX(TransIdOfMaxCust)
		FROM	@tmpBatch
		WHERE	BatchNo = @BatchNo

		SET @settlementTime = GETDATE();

		UPDATE b
			SET @modds = CASE 
							WHEN betteam = @result THEN 1
							WHEN bettype = 22 AND CHARINDEX((REPLACE(SUBSTRING(CAST(betID AS VARCHAR(10)),2,5),@bettype_22,@bettype_160) + betteam),@Result)> 0 THEN 1	
							ELSE -1
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
								WHEN @modds > 0 THEN actual_stake + stake * (CASE 
										WHEN odds < 0 THEN 1
										ELSE CASE 
												WHEN bettype IN (424,22,455) THEN odds - 1
												ELSE odds 
												END
										END
									)
								WHEN @modds < 0 THEN 0
							END
				,@statusId = CASE
								WHEN @modds > 0 THEN 112 --WON
								WHEN @modds < 0 THEN 113 --LOSE
							END
				,SettlementTime = CASE WHEN winlost <> @winlost OR statusID <> @statusId THEN @settlementTime ELSE SettlementTime END
				,winlost = @winlost
				,aWinLost = CASE 
				WHEN @modds > 0 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE CASE 
								WHEN bettype IN (424,22,455) THEN odds - 1
								ELSE odds
								END
						END
						) * - apositiontaking
				WHEN @modds < 0 THEN actual_stake * apositiontaking
				END, 

				mWinLost = CASE 
				WHEN @modds > 0 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE CASE 
								WHEN bettype IN (424,22,455) THEN odds - 1
								ELSE odds 
								END
						END
						) * - mpositiontaking
				WHEN @modds < 0 THEN actual_stake * mpositiontaking
				END,

				sWinLost = CASE 
				WHEN @modds > 0 THEN stake * (CASE 
						WHEN odds < 0 THEN 1
						ELSE CASE 
								WHEN bettype IN (424,22,455) THEN odds - 1
								ELSE odds 
								END
						END
						) * - spositiontaking
				WHEN @modds < 0 THEN actual_stake * spositiontaking
				END,

				PlayerComm = CASE 
				WHEN @modds > 0 THEN @commWinRate * playerdiscount * stake
				WHEN @modds < 0 THEN @commLostRate * playerdiscount * stake
				END, 

				Comm = CASE 
					WHEN @modds > 0 THEN @commWinRate * discount * stake * (1 - apositiontaking)
					WHEN @modds < 0 THEN @commLostRate * discount * stake * (1 - apositiontaking)
					END,

				aComm = CASE 
					WHEN @modds > 0 THEN @commWinRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
					WHEN @modds < 0 THEN @commLostRate * adiscount * stake * (1 - (mpositiontaking + apositiontaking))
					END,

				sComm = CASE 
					WHEN @modds > 0 THEN @commWinRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
					WHEN @modds < 0 THEN @commLostRate * sdiscount * stake * (1 - (spositiontaking + mpositiontaking + apositiontaking))
					END,

				Status = CASE
					WHEN @modds > 0 THEN N'WON'
					WHEN @modds < 0 THEN N'LOSE'
					END,

				StatusID = @statusId,
				ruben = 1
		FROM	@tmpBatch c
			INNER JOIN dbo.bettrans b WITH(ROWLOCK, UPDLOCK)
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
			OUTER APPLY (
				SELECT	TOP (1) mt.TransId
				FROM	dbo.MarkedTransaction mt WITH(NOLOCK)
				WHERE	mt.TransId = b.transid
						AND mt.CustId = c.custId
			) mt
		WHERE	matchid = @matchid 
				AND bettype = @bettype 
				AND 1 = CASE 
							WHEN @Bettype = 22 AND CHARINDEX(REPLACE(SUBSTRING(CAST(betID AS VARCHAR(20)),2,5),@bettype_22,@bettype_160),@ResourceIDs)>0 THEN 1 
							WHEN @Bettype <> 22 THEN 1 
							ELSE 0 END
				AND statusID NOT IN (101, 102)
				AND b.statusID = CASE WHEN @IsReSettledTickets = 0 THEN 0 ELSE b.statusID END
				AND mt.TransId IS NULL

		SET @BatchNo = @BatchNo - 1
	END
END

GO
