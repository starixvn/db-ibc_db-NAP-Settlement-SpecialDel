/*<info serverAlias="DBPRO-bodb02" executers="wsv_nap" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Set_ResultDetail3rd_Sel]
    @MatchID		INT
AS
/*	
	Creator: 20241023@Louisa 
	Task: new sporttype Virtual Basketball - 12 new bettypes 
	DB: DBPRO-bodb02
	
	Revision:
		- 20241023@Louisa: Initial [Redmine:#210733]
 
*/
BEGIN
	
	SELECT ResourceId AS Id
		, Custom1 AS Home
		, Custom2 AS Away
		, SettlementStatusID
	FROM dbo.ResultDetail3rd r WITH(NOLOCK)
	WHERE r.MatchID = @MatchID

END;
GO