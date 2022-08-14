/*<info serverAlias="DBTXN-bodb02" executers="" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Calculate_VS_BetRadar_Refund]
	@MatchId			INT				= 0
	,@SportType			INT				= 0
	,@TicketInfos 		VARCHAR(MAX)	= NULL
	,@mode 				VARCHAR(10)		= 'Refund'
	,@RefundBettypes	VARCHAR(MAX)	= ''
	,@maxTransId		BIGINT			= 0
	,@ActionID			TINYINT			= 0
	,@IsBalance			BIT 			= 1
	,@CWLBettype		SMALLINT 		= 1201
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	
	Created: 20160606@Bobby
	Task :  77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	Revisions:
		- 20160606@Bobby: Initialize
		- 20170607@Kent: Integrate Betradar Virtual Sports [Redmine:#77177]
		- 20180214@Helen: Integrate VSBR 2 - Basketball - [Redmine:90154]
		- 20220217@Kathy: Do not cal/refund if there is no ticket [Redmine:#168702]
		- 20220719@Louisa: Scale Out BetTrans [Redmine:#175251]
		
	Param's Explanation:
		• @Mode:
		Refund : Refund single ticket by match
		RECOVER : Refund single ticket by ticket list
		• @TicketInfos : 
		meaning : single transids (bettrans.transid)	
		format xml : <root><r t="2333" /></root>
*/
BEGIN
	SET NOCOUNT ON
	
	DECLARE @xmlBettype	 	XML
		, @xmlTicket		XML
		, @balanceAcc 		VARCHAR(MAX)
		, @balanceUpd		VARCHAR(MAX)
		, @balanceType		TINYINT
		, @batchCount		INT
		, @GroupID			INT
		, @IsCentral		BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT
		
	DECLARE @tempBettype 	TABLE (bettype SMALLINT)
	DECLARE @BetTickets  	TVP_Settlement_BetTicket
			
	CREATE TABLE #tblTicketInfos (transid BIGINT)		
	CREATE TABLE #tblTicketInfos_Top (transid BIGINT)
	
	SELECT @ErrCode 		= 0
			, @ErrMsg  		= ''
			, @balanceType 	= 4
			, @batchCount	= 2000
			, @balanceAcc   = ''
			, @GroupID		= 7 --VS Betradar

		
	IF @mode = 'Refund'
	BEGIN
		--CONVERT bettype
		
		SET @xmlBettype = CONVERT(XML, @RefundBettypes)
		;WITH CTE_Bettype AS (
			SELECT T.C.value('./@t', 'SMALLINT') AS bettype
			FROM @xmlBettype.nodes('/root/r') AS T(C)
		)
		INSERT INTO @tempBettype(bettype)
		SELECT temp.bettype
		FROM CTE_Bettype temp
			INNER JOIN dbo.f_Set_VS_BetRadar_GetBettypes () AS f
			ON temp.bettype = f.bettype
		WHERE f.SportType = @SportType	
		OPTION (OPTIMIZE FOR (@xmlBettype = NULL ))
		
		IF (@@ROWCOUNT = 0) RETURN
	END		
	ELSE IF @Mode = 'RECOVER'
	BEGIN
		--CONVERT Ticket
		SET @xmlTicket = CONVERT(XML, @TicketInfos)
		
		INSERT INTO #tblTicketInfos(transid)
		SELECT T.C.value('./@t', 'BIGINT') as transid					
		FROM @xmlTicket.nodes('/root/r') as [T](C) --T: table, C: column	
		OPTION (OPTIMIZE FOR (@xmlTicket = NULL ))
		
		IF (@@ROWCOUNT = 0) RETURN
	END
	ELSE
		RETURN					
	
	BEGIN TRY
		WHILE 1 = 1
		BEGIN
			
			SET @balanceUpd = NULL
			DELETE @BetTickets
			
			IF @mode = 'Refund'
			BEGIN
				INSERT INTO @BetTickets(recommend, matchid, custid, bettype, transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actual_stake)	
				SELECT TOP (@batchCount)
					recommend, matchid, custid, bettype, transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actual_stake
				FROM dbo.bettrans b WITH (NOLOCK)
				WHERE b.matchid = @matchid
					AND b.statusID NOT IN (103, 101, 102) 
					AND EXISTS (
						SELECT 1 FROM @tempBettype AS f
						WHERE f.bettype = b.bettype
					)
					AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
					
				IF @@ROWCOUNT = 0 BREAK	
			END
			ELSE IF @Mode = 'RECOVER'
			BEGIN
				DELETE #tblTicketInfos_Top
			
				DELETE TOP (@batchCount) #tblTicketInfos
				OUTPUT DELETED.transid 
				INTO #tblTicketInfos_Top(transid)
				
				INSERT INTO @BetTickets(recommend, matchid, custid, bettype, transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actual_stake)	
				SELECT recommend, matchid, custid, bettype, transid, winlost, awinlost, mwinlost, swinlost, playercomm, comm, acomm, scomm, statusid, modds, actual_stake
				FROM dbo.bettrans b WITH (NOLOCK) --(ROWLOCK, UPDLOCK)
				WHERE b.transid IN (SELECT transid FROM #tblTicketInfos_Top)
					AND b.statusID NOT IN (103, 101, 102) 					
			
				IF @@ROWCOUNT = 0 BREAK	
			END
			
			--REFUND tickets
			UPDATE @BetTickets
			SET statusID = 103
				,winlost = actual_stake
				,awinlost = 0
				,mwinlost = 0
				,swinlost = 0
				,playercomm = 0
				,comm = 0
				,acomm = 0
				,scomm = 0
	
			EXEC dbo.NAP_Admin_Calculate_Bettrans
				@BetTickets		= @BetTickets
				,@CWLBettype	= @CWLBettype
				,@balanceUpd 	= @balanceUpd OUTPUT
				,@ErrCode 		= @ErrCode OUTPUT
				,@ErrMsg 		= @ErrMsg OUTPUT
				
			--tracing updated balance ACC
			IF(@balanceUpd IS NOT NULL)
			BEGIN
				SET @balanceAcc += @balanceUpd
			END		
						
			IF (@ErrCode > 0 ) BREAK
		END
	END TRY
	BEGIN CATCH
		SELECT @ErrCode = ERROR_NUMBER()
			, @ErrMsg 	= ERROR_MESSAGE()
			
	END CATCH
		
	-- Settlement balance process
	IF(@IsBalance = 1)
	BEGIN
		EXEC dbo.NAP_Admin_Settlement_BalanceProcess
			@BalanceAcc				= @balanceAcc
			, @BalanceType			= @BalanceType
			, @actionId				= @actionId
			, @MatchID				= @MatchID	
			, @GroupID				= @GroupID
	END
END
GO
