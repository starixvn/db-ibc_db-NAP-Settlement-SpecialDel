CREATE PROCEDURE [NAP_Set_MatchBetStatusSel]
	@matchid VARCHAR(max),
	@bettype int = 14,
	@betstatus VARCHAR(8000) = '' OUTPUT
AS
	/*
		Crated: Kathy
		Date: 20140224
		Task: Get bet status on match
		DB: DBTXN/bodb02
		Original: Acc_Set_MatchBetStatusSel

		Revisions:
			- 20140428@Kathy: Add @bettype [Redmine:#14449]

		Parameter's Explanation:
	*/
BEGIN
	SET NOCOUNT ON
	DECLARE @intDocHandle INT

	--Create an internal representation of the XML document.      
	EXEC sp_xml_preparedocument @intDocHandle OUTPUT, @matchid
	
	;WITH t AS
	(
		SELECT matchid , COUNT(1) AS cnt
		FROM dbo.bettrans WITH(NOLOCK)
		WHERE matchid IN (
							SELECT matchid
							FROM OPENXML(@intDocHandle,'/root/match',2)
							with (matchid INT) 
						)
			AND bettype = @bettype
		GROUP BY matchid 
	)

	SELECT @betstatus = (
		SELECT * 
		FROM t
		FOR XML PATH('match'), ROOT('root')
	)
	
END
GO

GRANT EXECUTE ON [NAP_Set_MatchBetStatusSel] TO [bodbAdminNet] AS [dbo]
GO

GRANT VIEW DEFINITION ON [NAP_Set_MatchBetStatusSel] TO [vnteam] AS [dbo]
GO


