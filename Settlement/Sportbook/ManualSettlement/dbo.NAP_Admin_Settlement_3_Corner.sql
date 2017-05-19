ALTER PROCEDURE [dbo].[NAP_Admin_Settlement_3_Corner] @matchid INT
	,@mode VARCHAR(6) = 'CAL'
	,@isExcludeCorner	BIT = 0 
AS
/*
	Created: Jamie
	Task : Covered SP for settlement CORNER [Feature #38099]
	DB: DBTXN/bodb02

	Revisions:
		- 20160315@Patrick: Auto payout [Redmine: #53262]

	Param's Explanation:
	• @Mode:
		CAL : All BetTypes
*/
BEGIN
	SET NOCOUNT ON;

	-- result
	DECLARE 
			--corners bets
			 @fthCorners		INT = 0
			,@ftaCorners		INT = 0
			,@hthCorners		INT = 0
			,@htaCorners		INT = 0 	
			,@oddevenCorners	SMALLMONEY	
			,@oddevenCorners_ht	SMALLMONEY
			,@totalCorners		SMALLMONEY
			,@totalCorners_ht	SMALLMONEY
			,@FTFCorner			VARCHAR(10) =''
			,@FTLCorner			VARCHAR(10) =''
			,@HTFCorner			VARCHAR(10) =''
			,@HTLCorner			VARCHAR(10) =''

	--ticket count
	DECLARE  @betcount_194 	INT
			,@betcount_195 	INT
			,@betcount_196 	INT
			,@betcount_197 	INT
			,@betcount_198 	INT
			,@betcount_199 	INT
			,@betcount_200 	INT
			,@betcount_201 	INT
			,@betcount_202 	INT
			,@betcount_203 	INT
			,@betcount_204 	INT
			,@betcount_205 	INT
			,@betcount_206 	INT
			,@betcount_207 	INT
			,@betcount_208 	INT
			,@betcount_209 	INT

	SELECT	 @fthCorners	= ISNULL(MAX(CASE WHEN ResourceID ='04' THEN HomeValue ELSE 0 END),0)
			,@ftaCorners	= ISNULL(MAX(CASE WHEN ResourceID ='04' THEN AwayValue ELSE 0 END),0)
			,@hthCorners	= ISNULL(MAX(CASE WHEN ResourceID ='05' THEN HomeValue ELSE 0 END),0)
			,@htaCorners	= ISNULL(MAX(CASE WHEN ResourceID ='05' THEN AwayValue ELSE 0 END),0)
			,@FTFCorner		= ISNULL(MAX(CASE WHEN ResourceID ='206' THEN HomeValue ELSE '' END),'')
			,@HTFCorner		= ISNULL(MAX(CASE WHEN ResourceID ='207' THEN HomeValue ELSE '' END),'')
			,@FTLCorner		= ISNULL(MAX(CASE WHEN ResourceID ='208' THEN HomeValue ELSE '' END),'')
			,@HTLCorner		= ISNULL(MAX(CASE WHEN ResourceID ='209' THEN HomeValue ELSE '' END),'')
	FROM	DBPRO.BODB02.dbo.ResultDetail WITH (NOLOCK)
	WHERE	matchid = @matchid
			AND ResourceID IN ('04','05','206','207','208','209')
			AND SettlementStatusID = 4 

	SELECT	 @oddevenCorners	= ((@fthCorners + @ftaCorners)%2)
			,@oddevenCorners_ht	= ((@hthCorners + @htaCorners)%2)
			,@totalCorners		= (@fthCorners + @ftaCorners)
			,@totalCorners_ht	= (@hthCorners + @htaCorners)

	IF @mode IN ('CAL', 'CAL-FT')
	BEGIN
		SELECT @betcount_194 = ISNULL(SUM(CASE bettype WHEN 194 THEN 1 ELSE 0 END),0)
			, @betcount_195 = ISNULL(SUM(CASE bettype WHEN 195 THEN 1 ELSE 0 END),0)
			, @betcount_196 = ISNULL(SUM(CASE bettype WHEN 196 THEN 1 ELSE 0 END),0)
			, @betcount_197 = ISNULL(SUM(CASE bettype WHEN 197 THEN 1 ELSE 0 END),0)
			, @betcount_198 = ISNULL(SUM(CASE bettype WHEN 198 THEN 1 ELSE 0 END),0)
			, @betcount_199 = ISNULL(SUM(CASE bettype WHEN 199 THEN 1 ELSE 0 END),0)
			--, @betcount_200 = ISNULL(SUM(CASE bettype WHEN 200 THEN 1 ELSE 0 END),0)
			--, @betcount_201 = ISNULL(SUM(CASE bettype WHEN 201 THEN 1 ELSE 0 END),0)
			--, @betcount_202 = ISNULL(SUM(CASE bettype WHEN 202 THEN 1 ELSE 0 END),0)
			--, @betcount_203 = ISNULL(SUM(CASE bettype WHEN 203 THEN 1 ELSE 0 END),0)
			--, @betcount_204 = ISNULL(SUM(CASE bettype WHEN 204 THEN 1 ELSE 0 END),0)
			--, @betcount_205 = ISNULL(SUM(CASE bettype WHEN 205 THEN 1 ELSE 0 END),0)
			, @betcount_206 = ISNULL(SUM(CASE bettype WHEN 206 THEN 1 ELSE 0 END),0)
			--, @betcount_207 = ISNULL(SUM(CASE bettype WHEN 207 THEN 1 ELSE 0 END),0)
			, @betcount_208 = ISNULL(SUM(CASE bettype WHEN 208 THEN 1 ELSE 0 END),0)
			--, @betcount_209 = ISNULL(SUM(CASE bettype WHEN 209 THEN 1 ELSE 0 END),0)
		FROM bettrans WITH (NOLOCK)
		WHERE matchid = @matchid 
			AND bettype IN (194,195,196,197,198,199,206,208) 
	END
	
	IF @mode IN ('CAL-HT','CAL')
	BEGIN
		SELECT @betcount_200 = ISNULL(SUM(CASE bettype WHEN 200 THEN 1 ELSE 0 END),0)
			, @betcount_201 = ISNULL(SUM(CASE bettype WHEN 201 THEN 1 ELSE 0 END),0)
			, @betcount_202 = ISNULL(SUM(CASE bettype WHEN 202 THEN 1 ELSE 0 END),0)
			, @betcount_203 = ISNULL(SUM(CASE bettype WHEN 203 THEN 1 ELSE 0 END),0)
			, @betcount_204 = ISNULL(SUM(CASE bettype WHEN 204 THEN 1 ELSE 0 END),0)
			, @betcount_205 = ISNULL(SUM(CASE bettype WHEN 205 THEN 1 ELSE 0 END),0)
			, @betcount_207 = ISNULL(SUM(CASE bettype WHEN 207 THEN 1 ELSE 0 END),0)
			, @betcount_209 = ISNULL(SUM(CASE bettype WHEN 209 THEN 1 ELSE 0 END),0)
		FROM dbo.bettrans WITH (NOLOCK)
		WHERE matchid = @matchid 
			AND bettype IN (200,201,202,203,204,205,207,209) 
	END
	
	-- call execrep SP
	EXEC dbo.NAP_Admin_Calculate_Main @matchid = @matchid
		,@action = 'CAL-CORNER'
		,@mode = 'CAL'
		,@fthCorners = @fthCorners
		,@ftaCorners = @ftaCorners
		,@hthCorners = @hthCorners
		,@htaCorners = @htaCorners
		,@oddevenCorners = @oddevenCorners
		,@oddevenCorners_ht	= @oddevenCorners_ht
		,@totalCorners = @totalCorners
		,@totalCorners_ht = @totalCorners_ht
		,@ftFCorner = @ftFCorner
		,@ftLCorner = @ftLCorner
		,@htFCorner = @htFCorner
		,@htLCorner = @htLCorner
		,@betcount_194 	= @betcount_194
		,@betcount_195 	= @betcount_195
		,@betcount_196 	= @betcount_196
		,@betcount_197 	= @betcount_197
		,@betcount_198 	= @betcount_198
		,@betcount_199 	= @betcount_199
		,@betcount_200 	= @betcount_200
		,@betcount_201 	= @betcount_201
		,@betcount_202 	= @betcount_202
		,@betcount_203 	= @betcount_203
		,@betcount_204 	= @betcount_204
		,@betcount_205 	= @betcount_205
		,@betcount_206 	= @betcount_206
		,@betcount_207 	= @betcount_207
		,@betcount_208 	= @betcount_208
		,@betcount_209 	= @betcount_209
		,@CalledByBrokerService = 0 -- this one is called by NAP_Admin_Settlement_3 instead :)
END
GO
GRANT EXECUTE ON [dbo].[NAP_Admin_Settlement_3_Corner] TO [bodbAdminNet] AS [dbo]
GO
GRANT VIEW DEFINITION ON [dbo].[NAP_Admin_Settlement_3_Corner] TO [vnteam] AS [dbo]