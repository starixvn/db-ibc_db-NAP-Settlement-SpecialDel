/*<info serverAlias="DBCTG-bodb02" executers="bodbAdminNet" viewers="" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[ExecRep_NAP_Admin_06]
/*
	Created by: 20201006@Louisa
	Task: execRep SP for Settlement [Redmine:#140452]
	DB: DBTXN/bodb02
	
	Revisions:
		- 20201006@Louisa: SP for Settlement [Redmine:#140452]
		- 20231023@Kathy: Correct data Parlay [Redmine:#191873]

	Param's Explanation:
		- ExecRep SP: DBTrans_ExecRep
*/	
AS
BEGIN
	SET NOCOUNT ON
	/*
		UPDATE 	dbo.BetParlayResult WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 111
		WHERE 	RefNo IN (11072093365993477)
				AND Serial IN (4040001)
			
		UPDATE 	dbo.BetParlayResult WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 111
		WHERE 	RefNo IN (11074099384156162)
				AND Serial IN (5050001)
			
			
		UPDATE 	dbo.BetParlayResult WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 111
		WHERE 	RefNo IN (11055243672420357)
				AND Serial IN (4040001)
	*/

	UPDATE 	dbo.BetParlayResult WITH(ROWLOCK, UPDLOCK)
			SET StatusId = 111
		WHERE 	RefNo IN (11127579780055042)
				AND Serial IN (8040060)

END
GO

EXEC dbo.ExecRep_NAP_Admin_06
