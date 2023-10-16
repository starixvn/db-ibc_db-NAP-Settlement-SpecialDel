/*<info serverAlias="DBTXN-bodb02" executers="Dot_Member,bodbAdminNet" viewers="vnteam" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_VS_BetRadar] 
	@AdminId			INT
	,@MatchId			INT
	,@Fth				SMALLINT		= NULL
	,@Fta				SMALLINT		= NULL
	,@Hth				SMALLINT		= NULL
	,@Hta				SMALLINT		= NULL
	,@Action			VARCHAR(10)		= 'CAL'
	,@IP				VARCHAR(50)		= ''
	,@IsCalParlay		BIT 			= 0
	,@IsAuto			BIT				= 1
	,@IsQueued			BIT 			= 0
	,@KeyId				INT				= 0
	,@ResourceResult	VARCHAR(MAX)	= ''
	,@ErrCode			INT				= 0		OUTPUT
	,@ErrMsg			NVARCHAR(200)	= ''	OUTPUT
AS
/*	Creator: 20170106@Bobby
	Task: 77720 - Implement BetRadar VS League & Nation
	DB: DBTXN/BODB02
	
	Revisions:
		- 20160606@Bobby: Initialize
		- 20180214@Helen: Integrate VSBR 2 - Basketball - [Redmine:90154]
		- 20220217@Kathy: Do not cal/refund if there is no ticket [Redmine:#168702]
		- 20220513@Louisa: Change write log from exec dbo.WriteLog_UserLog  to exec LogDB.dbo.Logfile_V2 [Redmine:#172708]
		- 20220719@Kathy: Scale Out BetTrans [Redmine:#175251]
		- 20230214@Aries: Use Service Broker to Write Log to DB Log [Redmine: #187252]
		- 20231016@Aries: Auto Send Announcement When Refund VS [Redmine:#195333]
		
	Param's Explanation:
		- @Hth: Total score which home team scored in Half Time(HT)
		- @Hta: Total score which away team scored in Half Time(HT)
		- @Fth: Total score which home team scored in Full Time(FT)
		- @Fta: Total score which away team scored in Full Time(FT)
		- @Action: [CAL,REFUND]
		@ResourceResult='<Results>
                            <Resource ResourceId="00" Custom1="100" Custom2="106" />
                            <Resource ResourceId="01" Custom1="60" Custom2="41" />
                            <Resource ResourceId="280920" Custom1="H" Custom2="" />
                            <Resource ResourceId="280940" Custom1="A" Custom2="" />
                            <Resource ResourceId="280960" Custom1="N" Custom2="" />
                    </Results>'
*/
BEGIN
	SET NOCOUNT ON
	
	IF(@Action NOT IN ('CAL', 'REFUND'))
	BEGIN
		SELECT	 @ErrCode	= 1000001
				,@ErrMsg	= 'This action ''' + @Action + ''' does not support!'	
		RETURN
	END
	
	DECLARE  @Remark			VARCHAR(500)
			,@TicketCount		INT
			,@ActionId			INT
			,@avaiableProcess	BIT
			,@sportType			INT
			,@TotalAccount 		INT
			,@TotalAccount_BalanceUpdate INT
			,@settleBettypes	VARCHAR(MAX)
			,@VSType 			TINYINT
			,@strRefnos 		VARCHAR(MAX)
			,@maxTransId		BIGINT
			,@procName			NVARCHAR(128)
			,@recipients		VARCHAR(250)
			,@ResourceIDs		VARCHAR(100)
			,@xml XML
			,@IsCentral			BIT
	
	DECLARE @tempBetCount 		TABLE(bettype SMALLINT, custid INT, betcount INT, transid BIGINT)
	DECLARE @tempRefno			TABLE(refno BIGINT)
	DECLARE @tmpResult			TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))
	DECLARE @Resources_193		TABLE (ResourceID VARCHAR(100))
	
	CREATE TABLE #tblMatchProcess (matchid INT, KeyID TINYINT)
		
	SELECT @ErrCode				= 0
		, @ErrMsg				= ''
		, @procName				= OBJECT_NAME(@@PROCID)
	
	SELECT TOP 1 
		@sportType 	= sportType
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId
		
	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	IF @sportType = 193 AND @Action = 'CAL'
	BEGIN
		
		SET @xml = CONVERT(XML,@ResourceResult)
	
		INSERT INTO @Resources_193 VALUES ('280920'),('280940'),('280960')
		
		INSERT INTO @tmpResult (ResourceId, HomeValue, AwayValue)
		SELECT DISTINCT
			T.C.value('@ResourceId', 'VARCHAR(20)') AS ResourceId
			,T.C.value('@Custom1', 'VARCHAR(20)') AS HomeValue
			,T.C.value('@Custom2', 'VARCHAR(20)') AS AwayValue
		FROM @xml.nodes('/Results/Resource') AS T(C)
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )	
		
		SET @ResourceIDs = STUFF((SELECT ',' + ResourceId
							FROM @tmpResult
							WHERE ResourceId IN (SELECT ResourceID FROM @Resources_193)
							FOR XML PATH('')),1,1,'')
	END
			
	SELECT @ActionID = CASE @Action
							WHEN 'CAL'		THEN 187
							WHEN 'REFUND'	THEN 188
						END
			,@VSType 	= 2
						
	-- check and not allow attempt to settlement same game while it's still not finish
	INSERT INTO #tblMatchProcess(matchid, KeyID)
	SELECT	@matchid AS matchid
			,1 AS KeyId
		
	--check settlement process
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @avaiableProcess 	= @avaiableProcess OUTPUT
		, @ErrCode			= @ErrCode OUTPUT
		, @ErrMsg			= @ErrMsg OUTPUT

	IF(@ErrCode <> 0 OR @avaiableProcess = 0) RETURN
		
	INSERT INTO @tempBetCount (bettype, custid, betcount, transid)
	SELECT b.bettype, b.custid, COUNT(1), MAX(transid)
	FROM dbo.bettrans b WITH(NOLOCK)
	WHERE b.matchid = @matchid
			AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
			AND EXISTS (
				SELECT 1 
				FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
				WHERE f.bettype 	= b.bettype
					AND f.sportType = @sportType
			)
		AND b.statusId NOT IN (101, 102)
	GROUP BY b.bettype, b.custid
		
	SELECT @TicketCount 	= SUM(betcount)
		,@TotalAccount		= COUNT(DISTINCT custid)
		,@maxTransId		= MAX(transid)
	FROM @tempBetCount
	
	SELECT @settleBettypes = CAST((
				SELECT DISTINCT r.bettype AS '@t'
				FROM @tempBetCount AS r
				FOR XML PATH('r'), ROOT('root'), TYPE
			) AS VARCHAR(MAX))
			
	-----------------------------------------------------------
	-----------------------------------------------------------
	IF @Action = 'CAL'
	BEGIN
		IF ISNULL(@TicketCount,0) > 0
			EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_Main
				@MatchId		= @matchid
				,@SportType		= @sportType
				,@Mode			= @Action
				,@CALBettypes 	= @settleBettypes
				,@maxTransId	= @maxTransId
				,@ActionID		= @ActionID
				,@ResourceIDs	= @ResourceIDs
				,@ErrCode		= @ErrCode OUTPUT
				,@ErrMsg		= @ErrMsg OUTPUT
	END

	ELSE IF @Action = 'REFUND'
	BEGIN
		IF ISNULL(@TicketCount,0) > 0
			EXEC dbo.NAP_Admin_Calculate_VS_BetRadar_Refund 
				@matchid 			= @matchid
				,@SportType			= @sportType
				,@RefundBettypes 	= @settleBettypes
				,@maxTransId		= @maxTransId
				,@ActionID			= @ActionID
				,@ErrCode			= @ErrCode OUTPUT
				,@ErrMsg			= @ErrMsg OUTPUT
	END
	
	EXEC dbo.NAP_Admin_CheckingProcess
		@isExistMatch		= 1
		, @IsReleased		= 1
	
	DROP TABLE #tblMatchProcess
END
GO