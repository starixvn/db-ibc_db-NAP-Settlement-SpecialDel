/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE dbo.NAP_Set_ParlayLockingDel
	@Session	NVARCHAR(100)
AS
/*
	Created:20210830@Louisa
    Task: Delete dbo.ParlayLocking  [Redmineid:#160738]
    DB: DBTXN/bodb02
	
	Revisions:
		- 20210830@Louisa: Delete dbo.ParlayLocking [Redmineid:#160738]

	Param's Explanation: 

*/
BEGIN
	SET NOCOUNT ON

	DELETE p
	FROM dbo.ParlayLocking p  WITH(ROWLOCK, UPDLOCK)
	WHERE p.Session = @Session
	
END
GO
