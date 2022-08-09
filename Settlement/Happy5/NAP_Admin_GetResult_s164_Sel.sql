/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE NAP_Admin_GetResult_s164_Sel
	@MatchID	INT
AS
/*
	Creator: 20220719@Louisa
	Task: Scale Out BetTrans [Redmine:#175251]
	DB: DBTXN/bodb02
	Revisions:		
		- 20201216@Louisa: Get old result before re-settle Happy5 manually [Redmine:#175251]
	Param's explaination: 
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @remarkOldValue VARCHAR(MAX) = '',@remarkNewValue VARCHAR(MAX) = ''
	DECLARE @tmpOldResultDetail TABLE (Seq TINYINT, Number TINYINT)

	INSERT INTO @tmpOldResultDetail (Seq, Number)
	SELECT Seq, Number
	FROM dbo.bingoBall WITH (NOLOCK)
	WHERE matchid = @matchid

	--SELECT @remarkOldValue = @remarkOldValue + ', B' + CAST(Seq AS VARCHAR(5)) + '(' + CAST(Number AS VARCHAR(5)) + ')'
	--FROM @tmpOldResultDetail
	--WHERE Number > 0 --AND @IsAuto = 0


END
GO