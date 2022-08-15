/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_Validation_MP
(
	 @matchids		VARCHAR(4000) = ''
	,@matchid		INT			 = 0
	,@Action		VARCHAR(10)
	,@Mode			VARCHAR(10)
	,@ErrCode		INT		= 0				OUTPUT
	,@ErrMsg		NVARCHAR(500)  = ''		OUTPUT
	,@MatchIdsValid VARCHAR(500) = ''		OUTPUT
	,@MatchIdsInValid	VARCHAR(500) = ''	OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before call SP MP_Push  [Redmine:#175251]

	Param's Explanation:
		@Action:  REFUND-FT, REFUND, CAL

*/

BEGIN
SET NOCOUNT ON

	DECLARE @matchcode			NVARCHAR(50)
			,@HoldSettingMatchIds VARCHAR(200) = ''

	CREATE TABLE #tblValidMatch (matchid INT, matchcode NVARCHAR(50) ,sporttype SMALLINT ,SettlementStatus	TINYINT ,ParentId INT )
	CREATE TABLE #tblInValidMatch (matchid INT	,matchcode NVARCHAR(50) )

	INSERT INTO #tblValidMatch ( matchid, matchcode, sporttype, SettlementStatus, ParentId)
	SELECT matchid
			,matchcode
			,sporttype
			,ISNULL(SettlementStatus,0) SettlementStatus
			,CASE WHEN ISNULL(ChildMatchType,0) = 200 AND m.ParentId IS NOT NULL AND m.sporttype = 50 THEN m.ParentId ELSE m.MatchId END ParentId
	FROM dbo.Match m WITH (NOLOCK)
			INNER JOIN (SELECT value FROM STRING_SPLIT(@matchids , ',')) tm
				ON m.matchid = tm.value

	
	SELECT @HoldSettingMatchIds = COALESCE(@HoldSettingMatchIds + ',' + m.matchcode, m.matchcode)
	FROM	#tblValidMatch m
	WHERE m.SettlementStatus & 87 > 0

	DELETE FROM #tblValidMatch
	OUTPUT deleted.matchid
	INTO #tblInValidMatch
	WHERE	SettlementStatus & 87 > 0

	
	IF ( ISNULL(@HoldSettingMatchIds,'') <> '' )
	BEGIN
		SELECT   @ErrCode = 1001011
				,@ErrMsg = CASE WHEN ISNULL(@HoldSettingMatchIds, '') <> ''
									THEN '(on hold): ' + STUFF(@HoldSettingMatchIds, 1, 1, '')
									ELSE ''
								END					
		END

	SELECT @MatchIdsInValid =  @MatchIdsInValid + ',' + Matchid FROM #tblInValidMatch
	SET @MatchIdsValid = SUBSTRING(@MatchIdsValid, 2, LEN(@MatchIdsValid))

	SELECT @MatchIdsValid =  @MatchIdsValid + ',' + Matchid FROM #tblValidMatch
	SET @MatchIdsValid = SUBSTRING(@MatchIdsValid, 2, LEN(@MatchIdsValid))

END
GO