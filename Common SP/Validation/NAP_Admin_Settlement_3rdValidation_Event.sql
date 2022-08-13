/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_3rdValidation_Event
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@IsAuto		BIT = 0
	,@SPName		VARCHAR(255)
	,@SelectedResources	VARCHAR(MAX) = NULL
	,@ErrCode				INT		 = 0 OUTPUT
	,@ErrMsg				NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation event before settle 3rd [Redmine:#175251]

	Param's Explanation:
		@Action: CAL, REFUND,			

		@Mode: 
			'164' : Happy5
			'175' : Bitcoint
			
			'193' : VS Betrardar
			'VS1' : Virtual soccer/Tennis

		@SelectedResources: 
			happy5:
				'<Resources>
						<Resource Id="1" Result="1" /><Resource Id="2" Result="2" /><Resource Id="3" Result="3" /><Resource Id="4" Result="4" />
						<Resource Id="5" Result="5" />
					  </Resources>'
			Pingoal: 
				@Action = 'CAL'
					<Resources>
							<Resource Id="00" Home="1" Away="3" /> <Resource Id="01" Home="1" Away="2" />
					</Resources>
				@Action = 'REFUND'
					<Resources>
							<Resource Id="00" Home="" Away="" /><Resource Id="01" Home="" Away="" />
					</Resources>

			VS Betrardar
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

	IF @Mode IN ( 'outright' , '175', '193')
	RETURN

	--------------------------------------------

	DECLARE @ActionId	INT		
			,@sportType	INT
			,@xmlData	XML
			,@FTHome	INT 
			,@FTAway    INT
			,@HTHome    INT
			,@HTAway    INT
	
	SET @xmlData = CONVERT(XML,@SelectedResources)

	SELECT @sportType 		= sportType
	FROM dbo.match m WITH(NOLOCK) 
	WHERE m.matchid = @MatchId

	--invalid ball
	IF @Mode = '164' AND @Action LIKE 'CAL%'
	BEGIN
		DECLARE @tmpResultDetail TABLE (ResourceID VARCHAR(20), Result1 VARCHAR(50), Result2 VARCHAR(50), isSourceFromDB BIT)
		
		INSERT INTO @tmpResultDetail(ResourceID, Result1, isSourceFromDB)
		SELECT  Seq, Number, 1
		FROM	dbo.BingoBall b WITH (NOLOCK)
		WHERE matchid = @matchid


		IF NOT EXISTS (SELECT TOP 1 1 FROM @tmpResultDetail) 
		BEGIN
			SELECT	@ErrCode = 1000001
					,@ErrMsg	= 'Ball number is required.'
		END
		
		SELECT @ErrCode = 1000002
				,@ErrMsg = 'Data is not valid'
		FROM @tmpResultDetail
		HAVING COUNT(*) <> 5
			
		SELECT @ErrCode = 1000002
				,@ErrMsg = 'Duplicate ball numbers'
		FROM @tmpResultDetail
		GROUP BY Result1
		HAVING COUNT(Result1) > 1
			
		SELECT @ErrCode = 1000002
				,@ErrMsg = 'Ball number must be from 1 to 20'
		FROM @tmpResultDetail
		WHERE Result1 < 1 OR Result1 > 20
		
		IF @ErrCode <> 0
			RETURN
	END


	IF @Mode = '193'
	BEGIN
		DECLARE @Resources_193 TABLE (ResourceID VARCHAR(100))
		DECLARE @tmpResult TABLE (ResourceId VARCHAR(20), HomeValue VARCHAR(20), AwayValue VARCHAR(20))

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
	
		INSERT INTO @Resources_193 
		VALUES ('280920'),('280940'),('280960')
		
		INSERT INTO @tmpResult (ResourceId, HomeValue, AwayValue)
		SELECT DISTINCT
			T.C.value('@ResourceId', 'VARCHAR(20)') AS ResourceId
			,T.C.value('@Custom1', 'VARCHAR(20)') AS HomeValue
			,T.C.value('@Custom2', 'VARCHAR(20)') AS AwayValue
		FROM @xmlData.nodes('/Results/Resource') AS T(C)
		OPTION ( OPTIMIZE FOR ( @xmlData = NULL ) )	
		
		SET @FTHome = (SELECT HomeValue FROM @tmpResult WHERE ResourceId = '00')
		SET @FTAway = (SELECT AwayValue FROM @tmpResult WHERE ResourceId = '00')
		SET @HTHome = (SELECT HomeValue FROM @tmpResult WHERE ResourceId = '01')
		SET @HTAway = (SELECT AwayValue FROM @tmpResult WHERE ResourceId = '01')


		IF(@Action = 'CAL' AND (@FTHome IS NULL OR @FTAway IS NULL OR @HTHome IS NULL OR @HTAway IS NULL))
		BEGIN
			SELECT	 @ErrCode	= 1000003
					,@ErrMsg	= 'The input score values are not valid!'	
			RETURN
		END

		IF @Action = 'CAL' 
			AND EXISTS (SELECT COUNT(1) FROM @tmpResult	GROUP BY ResourceId HAVING COUNT(1)> 1)
		BEGIN
			SELECT	 @ErrCode	= 1000006
					,@ErrMsg	= 'Inputed results are duplicate!'	
			RETURN
		END	

		IF EXISTS (SELECT 1 FROM @tmpResult 
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
		
		IF EXISTS (SELECT 1 FROM @tmpResult 
					WHERE ResourceId IN ('280920','280940','280960')
						AND HomeValue NOT IN ('H','A','N') 
					)		
		BEGIN
			SELECT	 @ErrCode	= 1000005
					,@ErrMsg	= 'Result not found!'	
			RETURN
		END

	END
	--/End check VR Beradar

	IF @Mode IN ( 'VS1' )
	BEGIN
		IF NOT EXISTS (SELECT TOP 1 1 FROM dbo.match m with(NOLOCK) WHERE m.matchid = @MatchId)
		BEGIN
			SELECT	 @ErrCode	= 1000001
					,@ErrMsg	= 'Match does not exist!'			
			RETURN
		END 
	END
END
GO