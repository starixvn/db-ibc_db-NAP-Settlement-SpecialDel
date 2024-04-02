/*<info serverAlias="DBCUST-SiteConfig" executers="wsv_nap" isFunction="0"></info>*/
ALTER PROCEDURE dbo.TicketVoiding_Email_OperatorInfo_Select 
    @AgentIdsXml XML
AS
/*
	Create By: Zane
	Created Date: 20200917
	Task: Show operatorID into void email - [Redmine: #141126]
	DB: DBCUST/SiteConfig
	
	Revisions: 
		- 20200917@Zane: Create new SP [Redmine: #141126]

	Param's explanation:
*/
BEGIN
	SET NOCOUNT ON

	CREATE TABLE #tblAgentIds (AgentId INT);
	
	INSERT INTO #tblAgentIds (AgentId)
	SELECT T.C.value('@AgentId', 'INT')
	FROM @AgentIdsXml.nodes('/Operators/Operator') AS T(C)
	OPTION ( OPTIMIZE FOR ( @AgentIdsXml = NULL ) )

	-- Return data
	SELECT tb.AgentId, op.OperatorID
	FROM #tblAgentIds tb
		LEFT JOIN dbo.Operator op WITH(NOLOCK) ON tb.AgentId = op.AgentID

	DROP TABLE #tblAgentIds
END