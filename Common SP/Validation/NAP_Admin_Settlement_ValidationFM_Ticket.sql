/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" IsNested="1"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_ValidationFM_Ticket
(
	 @matchid		INT = 0
	,@Action		VARCHAR(10)
	,@IsAuto		BIT = 0
	,@SelectedResources		VARCHAR(MAX) = NULL
	,@IsSettleDetermined	BIT	= 0
	,@ErrCode		INT		= 0     OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation Fastmarket [Redmine:#175251]

	Param's Explanation:

*/
BEGIN
	SET NOCOUNT ON

	DECLARE @xmlResourceResult	XML
			,@IsFailed			BIT = 0
			,@subErrMsg		VARCHAR(MAX) = ''

			-- bettype 228
			,@BetOption1st	VARCHAR(50)
			,@BetOption2nd	VARCHAR(50)
			,@ResultStatus1st VARCHAR(50)			
			,@ResultStatus2nd VARCHAR(50)
			,@minSelectedPosition TINYINT
			,@maxSelectedPosition TINYINT

			-- bettype 229
			,@BetOptionHome_1st VARCHAR(50)
			,@BetOptionHome_2nd VARCHAR(50)
			,@BetOptionAway_1st VARCHAR(50)
			,@BetOptionAway_2nd VARCHAR(50)

	DECLARE @tblFM_Data TABLE (
			bettype					SMALLINT
			,ResourceId				VARCHAR(20)
			,ResourceId_BetOption	VARCHAR(20)
			,Position				TINYINT
			,BetOption				TINYINT
			,ResultStatus			TINYINT
		)

	DECLARE @tblResultDetail TABLE (
		ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,OtherInfo		VARCHAR(50)
	)

	DECLARE @tblSpecialResultDetail TABLE (
		ResourceId		VARCHAR(20)
		,HomeValue		VARCHAR(50)
		,AwayValue		VARCHAR(50)
		,OtherInfo		VARCHAR(50)
	)
	
	DECLARE @tblResultDetail_228 TABLE (
		ResourceId				VARCHAR(20)
		,Position				TINYINT 
		,Value					TINYINT
	)

	DECLARE @tblResultDetail_229 TABLE (
		ResourceId				VARCHAR(20)
		,Position				TINYINT 
		,Value					TINYINT
	)

	SET @xmlResourceResult = CONVERT(XML, @SelectedResources)
	
	INSERT INTO @tblResultDetail (ResourceId, HomeValue, AwayValue, OtherInfo)
	SELECT	ResourceId, HomeValue, AwayValue, OtherInfo
	FROM	dbo.ResultDetail r WITH (ROWLOCK)
	WHERE	matchid = @matchid

	;WITH TmpData AS (
		SELECT T.C.value('@Id', 'SMALLINT') AS Bettype
			,X.C.value('@Position','TINYINT') as Position
			,X.C.value('@Result','TINYINT') as BetOption
		FROM @xmlResourceResult.nodes('/BetTypes/BetType') AS T(C)
			CROSS APPLY
				C.nodes('Item') AS X(C)
	)
	INSERT INTO @tblFM_Data (bettype, ResourceId, ResourceId_BetOption, Position, BetOption)
	SELECT	bettype
			,CAST(BetType * 100 AS VARCHAR(20)) AS ResourceId
			,CASE WHEN bettype = 229 THEN '22901H' ELSE CAST(BetType * 100 + 1 AS VARCHAR(20)) END AS ResourceId_BetOption
			,Position
			,BetOption
	FROM TmpData t
	OPTION ( OPTIMIZE FOR ( @xmlResourceResult = NULL ) )

	IF @IsAuto = 1
	BEGIN		
		-- For bettype between 221 and 227	
		UPDATE t
			SET	BetOption = (SELECT TOP 1 byte 
							 FROM dbo.f_Set_GetByte(CASE 
														WHEN t.Position <= 44 THEN r.HomeValue 
														ELSE AwayValue 
													END, t.Position)
												)
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId_BetOption
		WHERE	r.ResourceId NOT LIKE '22[8-9]01%'
				
		UPDATE t
		SET	ResultStatus = (SELECT TOP 1 [char] 
							 FROM dbo.f_Set_GetChar(CASE 
														WHEN t.Position <=44 THEN r.HomeValue 
														ELSE r.AwayValue 
													END, CASE WHEN t.Position <=44 THEN t.Position ELSE t.Position - 45 END)
												)
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail r
				ON r.ResourceId = t.ResourceId
		WHERE	r.ResourceId NOT LIKE '22[8-9]00'
		-- end update for bettype between 221 and 227

		--For bettype 228
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_228 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22801'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_228 r 
				ON	r.ResourceId = t.ResourceId 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22800'
		-- end update for bettype 228

		--For bettype 229
		UPDATE t
			SET BetOption = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_229 r
				ON	r.ResourceId = t.ResourceId_BetOption 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22901H'

		UPDATE t
			SET ResultStatus = r.Value
		FROM	@tblFM_Data t
			INNER JOIN @tblResultDetail_229 r 
				ON	r.ResourceId = t.ResourceId 
					AND t.Position = r.Position
		WHERE	r.ResourceId = '22900'
		-- end update for bettype 229
		
		DELETE 
		FROM @tblFM_Data
		WHERE	(ResultStatus IN (3,5,6,7) OR BetOption = 0) AND bettype NOT IN (228, 229)
	END

	SET @SelectedResources = CAST((
				SELECT bettype '@Id'
					,(SELECT Position '@p'
							,BetOption '@r'
							,CASE WHEN r.bettype = 229 THEN 0 ELSE @IsSettleDetermined END AS '@s'
							,CASE WHEN r.bettype IN (228, 229) THEN 1 ELSE NULL END AS '@i' -- HasInjuryTime
						FROM @tblFM_Data WHERE r.bettype = bettype FOR XML PATH('r'), TYPE)
				FROM @tblFM_Data r
				GROUP BY r.bettype
				FOR XML PATH('b'), ROOT ('r'), TYPE
			) AS VARCHAR(MAX))

	EXEC dbo.NAP_Admin_Settlement_Checking 
		@MatchId = @MatchId
		,@xmlData = @SelectedResources
		,@Action = @Action
		,@Mode = 'FM'
		,@IsAuto = @IsAuto
		,@ErrCode = @ErrCode OUTPUT
		,@ErrMsg = @ErrMsg OUTPUT

	RETURN


END
GO