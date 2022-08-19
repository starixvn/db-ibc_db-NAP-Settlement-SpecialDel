/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_Settlement_VS1_Validation_Event
(
	 @matchid		INT = 0
	,@ErrCode		INT		 = 0 OUTPUT
	,@ErrMsg		NVARCHAR(300)  = ''    OUTPUT
)
AS
/*
	Created: 20220719@Louisa
    Task: Scale Out BetTrans [Redmine:#175251]
    DB: DBPRO/bodb02
	
	Revisions:
		- 20220719@Louisa: Validation before settle [Redmine:#175251]

	Param's Explanation:
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @sportType		INT

	SELECT @sportType 		= m.sportType
	FROM dbo.match m WITH(NOLOCK) 
		INNER JOIN dbo.league l WITH(NOLOCK)
			ON m.leagueid = l.leagueid
	WHERE m.matchid = @MatchId

	IF ISNULL(@sportType,0) = 0
	BEGIN
		SELECT	 @ErrCode	= 1000001
				,@ErrMsg	= 'Match does not exist!'			
		RETURN
	END 

END
GO