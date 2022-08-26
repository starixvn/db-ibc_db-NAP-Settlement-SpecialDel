/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_s193_Validation
(
	 @matchid				INT = 0
	 ,@Action			VARCHAR(10)		= 'CAL'
	 ,@Fth				SMALLINT		= NULL
	 ,@Fta				SMALLINT		= NULL
	 ,@Hth				SMALLINT		= NULL
	 ,@Hta				SMALLINT		= NULL
	 ,@SelectedResources		VARCHAR(MAX)	= NULL
	 ,@ErrCode				INT				= 0		OUTPUT
	 ,@ErrMsg				NVARCHAR(300)	= ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle 3rd [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, REFUND,			
 

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sporttype		SMALLINT
			,@xml			XML
			,@ResourceIDs VARCHAR(100)
			,@IsCentral		BIT = 0

	EXEC dbo.NAP_Set_ServerInfo
		@IsCentral = @IsCentral OUTPUT

	DECLARE @tmpResultVS TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))
	DECLARE @Resources_193 TABLE (ResourceID VARCHAR(100))

	SELECT	@sportType 	= sportType
	FROM	dbo.match m WITH(NOLOCK) 
	WHERE	m.matchid = @MatchId

	IF(@Action NOT IN ('CAL', 'REFUND'))
	BEGIN
		SELECT	 @ErrCode	= 1000001
				,@ErrMsg	= 'This action ''' + @Action + ''' does not support!'	
		RETURN
	END

	IF (@sportType IS NULL OR @sportType NOT BETWEEN 190 AND 199)
	BEGIN
		SELECT	 @ErrCode	= 1000002
				,@ErrMsg	= 'Match does not exist or the sport type is not valid!'	
		RETURN
	END 

	IF @sporttype = 193
	BEGIN
		
		--start check invalid result
		SET @xml = CONVERT(XML,@SelectedResources)
		
		INSERT INTO @Resources_193 
		VALUES ('280920'),('280940'),('280960')

		INSERT INTO @tmpResultVS (ResourceId, HomeValue, AwayValue)
		SELECT DISTINCT
			T.C.value('@ResourceId', 'VARCHAR(20)') AS ResourceId
			,T.C.value('@Custom1', 'VARCHAR(20)') AS HomeValue
			,T.C.value('@Custom2', 'VARCHAR(20)') AS AwayValue
		FROM @xml.nodes('/Results/Resource') AS T(C)
		OPTION ( OPTIMIZE FOR ( @xml = NULL ) )	
		
		IF EXISTS (SELECT 1 FROM @tmpResultVS 
					WHERE ResourceId IN ('00','01') 
							AND (	HomeValue = '' 
									OR AwayValue = '' 
									OR ISNUMERIC(HomeValue) = 0 
									OR ISNUMERIC(AwayValue) = 0
								)
					)
		BEGIN
			SELECT	 @ErrCode	= 1000003
					,@ErrMsg	= 'The input score values are not valid!'
			RETURN			
		END

		IF EXISTS (SELECT 1 FROM @tmpResultVS 
					WHERE ResourceId IN ('280920','280940','280960')
						AND HomeValue NOT IN ('H','A','N')
					)		
		BEGIN
			SELECT	 @ErrCode	= 1000005
					,@ErrMsg	= 'Result not found!'
			RETURN
		END

		SET @Fth = (SELECT HomeValue FROM @tmpResultVS WHERE ResourceId = '00')
		SET @Fta = (SELECT AwayValue FROM @tmpResultVS WHERE ResourceId = '00')
		SET @Hth = (SELECT HomeValue FROM @tmpResultVS WHERE ResourceId = '01')
		SET @Hta = (SELECT AwayValue FROM @tmpResultVS WHERE ResourceId = '01')

		SET @ResourceIDs = STUFF((SELECT ',' + ResourceId
							FROM @tmpResultVS
							WHERE ResourceId IN (SELECT ResourceID FROM @Resources_193)
							FOR XML PATH('')),1,1,'')
	END

	--CHECK: HOME, AWAY scores validation
	IF(@Action = 'CAL' AND (@Fth IS NULL OR @Fta IS NULL OR @Hth IS NULL OR @Hta IS NULL))
	BEGIN
		SELECT	 @ErrCode	= 1000003
				,@ErrMsg	= 'The input score values are not valid!'	
		RETURN
	END

	IF @sportType = 193 AND @Action = 'CAL'
	BEGIN

		IF EXISTS (SELECT COUNT(1) 
					FROM @tmpResultVS
					GROUP BY ResourceId
					HAVING COUNT(1)> 1)
		BEGIN
			SELECT	 @ErrCode	= 1000006
					,@ErrMsg	= 'Inputed results are duplicate!'	
			RETURN
		END

		IF ISNULL((SELECT COUNT(1) 
					FROM @tmpResultVS 
					WHERE ResourceId IN (SELECT ResourceID FROM @Resources_193)),0) < 3
		BEGIN
			-- Single Ticket: Checking Ticket if resources not exist
			IF EXISTS (SELECT TOP 1 1 
						FROM bettrans b (nolock)
						WHERE b.matchid = @MatchId
							AND b.statusId NOT IN (101, 102)
							AND b.betid IN ('820','840','860')
							AND EXISTS (SELECT 1 
										FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
										WHERE f.bettype 	= b.bettype
											AND f.sportType = @sportType)
							
							AND (@ResourceIDs IS NULL OR CHARINDEX (RIGHT(BETID,2),@ResourceIDs)= 0)
							AND b.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE b.SiteDBGroupID END
						) 						
			BEGIN
				SELECT	 @ErrCode	= 1000005
						,@ErrMsg	= 'Result not found!'	
				RETURN
			END
			
			-- Parlay Ticket: Checking Ticket if resources not exist
			IF EXISTS (SELECT TOP 1 1 
						FROM bettransm bm (nolock)
						WHERE bm.matchid = @MatchId
							AND bm.statusId NOT IN (101, 102)
							AND bm.betcheck IN ('820','840','860')
							AND EXISTS (SELECT 1 
										FROM dbo.f_Set_VS_BetRadar_GetBettypes() AS f
										WHERE f.bettype 	= bm.bettype
											AND f.sportType = @sportType)
							
							AND (@ResourceIDs IS NULL OR CHARINDEX (RIGHT(betcheck,2),@ResourceIDs)= 0)
							AND bm.SiteDBGroupID = CASE WHEN @IsCentral = 1 THEN 0 ELSE bm.SiteDBGroupID END
						) 						
			BEGIN
				SELECT	 @ErrCode	= 1000005
						,@ErrMsg	= 'Result not found!'	
				RETURN
			END
			
		END
		--/end 
	END

	--/startcheck match in queue
	IF EXISTS (
        SELECT	1
        FROM	dbo.Single_Calculate_Queue_VS WITH (NOLOCK)
        WHERE	matchid = @matchid
				AND IsCalculating IN (0, 1)
        )
    OR EXISTS (
        SELECT	1
        FROM	dbo.Parlay_Calculate_Queue_VS WITH (NOLOCK)
        WHERE	matchid = @matchid
				AND IsCalculating IN (0, 1)
        )
	BEGIN
		SELECT	@ErrCode = 1001004
				,@ErrMsg    = 'This match is being calculated, please wait a few seconds until the on-going process is completed and try again.'
		RETURN
	END
	--/end check match in queue
END
GO