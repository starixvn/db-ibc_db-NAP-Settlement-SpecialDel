/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_SiteDBServiceLog_Checking
	@LogIds			VARCHAR(500)
	,@SiteDBGroupId SMALLINT
	,@IsPass		BIT  = 0 OUTPUT
AS
/*
	Created:20221122@Louisa
    Task: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]
    DB: DBSIG/bodb02
	
	Revisions:
		- 20221122@Louisa: Internal tool to update SiteDB_SettlementService_LastLog [RedmineId:#180746]

	Param's Explanation:
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @CheckDate DATETIME =  DATEADD ( HOUR, - 1, GETDATE() )
	;WITH cte_LogId (LogId )
	AS 
	(
		SELECT DISTINCT Value FROM string_split(@LogIds, ',')
	)

	SELECT @IsPass =  (		SELECT TOP 1  1
							FROM dbo.SiteDB_SettlementService_CalculationLog_History h WITH(NOLOCK)
								LEFT JOIN cte_LogId l ON h.LogId = l.LogId
									AND @SiteDBGroupId = h.SiteDBGroupId
									AND h.LogDate  > @CheckDate
							WHERE h.LogId IS NULL
						)

END
GO