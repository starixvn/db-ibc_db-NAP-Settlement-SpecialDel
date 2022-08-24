/*<info serverAlias="DBPRO-bodb02" executers="bodbAdminNet" viewers="" isFunction="0" isNested="1"></info>*/
ALTER PROCEDURE [dbo].[NAP_Admin_Match3rd_Update]
    @MatchID    INT,
	@Action		VARCHAR(20) = 'CAL'
AS
/*
    Created: 20210810@Kathy
    Task : Update information into match3rd table (when run settlement)
    DB: DBPRO/bodb02
   

    Revisions:
       - 20210810@Kathy: Incorporate Bitcoin  [Redmine:#159714]
	   - 20211108@Louisa: In-house Replicator: Updated Action [Redmine:#164393] 
		
    Parameters Explanation:


*/
BEGIN
    SET NOCOUNT ON

	UPDATE m 
		SET	eventstatus = 'completed'
			,betstatus = CASE WHEN @Action = 'REFUND' THEN 'Refund' ELSE NULL END
			,UpdateTime = GETDATE()
	FROM	dbo.match3rd m WITH(ROWLOCK, UPDLOCK)
	WHERE	m.Match3rdId = @MatchId

END
GO