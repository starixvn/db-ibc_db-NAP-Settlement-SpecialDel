/*<info serverAlias="DBCTG-bodb02,DBSIG-bodb02" executers="" viewers="" isFunction="0"></info>*/  
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_06]
/*
	Created by: 20201006@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20240626@Kathy: update winlostdate
		- 20251105@Louisa: issue ticket on DBTrans does not move to bettrans14 even SiteDB was moved [Redmine:#243637]
		- 20251125@Helen: running ticket for parlay, sub already move to 14  [Redmine:#0000]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep
*/	
AS
BEGIN
	SET NOCOUNT ON

	IF OBJECT_ID (N'BetParlayResult', N'U') IS NULL 
		RETURN
	
	IF @@SERVERNAME NOT LIKE 'DB04%'
		AND @@SERVERNAME NOT IN ('DB054', 'DB054C2\DB054', 'DB055', 'SITDB055')
		AND @@SERVERNAME NOT LIKE 'SITDB04%'
	BEGIN 

		DECLARE @refnos_29				VARCHAR(MAX) = '',
				@MainParlay_MaxPO		VARCHAR(MAX) = NULL
				,@IsSiteDB			BIT = 0
			
		IF OBJECT_ID('SiteDB_SettlementService_CalculationLog','U') IS NOT NULL 
			SET @IsSiteDB = 1

		CREATE TABLE #tblMainTicket
		(
			TransId		BIGINT
			,Refno		BIGINT
		)
		INSERT INTO #tblMainTicket (transid, refno)
		SELECT 457368430245314578, 28585526890070019

		SELECT @refnos_29 = @refnos_29 + CONVERT(VARCHAR(50),refno) + '|' + CONVERT(VARCHAR(50),transid) + ','
		FROM #tblMainTicket
	
		-- Update BetparlayResult
		UPDATE r	
			SET statusid = 113, awinlost = 9.2000
		FROM betparlayresult r WITH (ROWLOCK,UPDLOCK)
		WHERE refno= 28585526890070019 AND r.serial = 4030001
	    
		--Call cal_29: resettle for main ticket
		IF @IsSiteDB = 1
		BEGIN
			EXEC dbo.NAP_Admin_Calculate_MP_broker
				@matchdate = '2025-11-24' -- main transid + refno: refno|transid,refno|transid...
				, @strXML	   = @refnos_29
				, @mode	   = '29'
				, @IsCalculateBalance = 1
				, @AffectedTransIds = @MainParlay_MaxPO OUTPUT
		
			--Insert max payout queue
			IF ISNULL(@MainParlay_MaxPO, '') <> ''
			BEGIN
				EXEC dbo.NAP_Set_CustLimitBetQueue_Insert_Parlay
					@TransIds = @MainParlay_MaxPO
			END
		END
	END
END