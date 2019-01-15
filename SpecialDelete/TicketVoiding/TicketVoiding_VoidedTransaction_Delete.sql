/*<info serverAlias="DBTXN-bodb02" executers="bodbAdminNet" isFunction="0"></info>*/
ALTER PROCEDURE [dbo].[TicketVoiding_VoidedTransaction_Delete]
	@TransIds		VARCHAR(MAX)					
	,@MatchId		INT = 0
AS
/*	Created by: Kathy
	Date 20181212
	Task: remove voided transaction after recovering [Redmine:#106655]
	DB: DBTXN/bodb02
	
	Revisions: 
		- 20181221@Kathy: Create new SP [Redmine:#106655]
	
	Param's explanation:	
		
*/
BEGIN
	SET NOCOUNT ON

	DECLARE @tmpTransId TABLE (TransId BIGINT)

	INSERT INTO @tmpTransId(TransId)
	SELECT	val
	FROM	dbo.f_SplitString(@TransIds, ',')
	OPTION (maxrecursion 0)

	WHILE (1=1)
	BEGIN
		DELETE TOP (1000) vt
		FROM	@tmpTransId t
			INNER JOIN dbo.TicketVoiding_VoidedTransaction vt WITH(ROWLOCK, UPDLOCK)
				ON vt.TransId = t.TransId
		WHERE	vt.MatchId = @MatchId

		IF @@ROWCOUNT < 1000
			BREAK
	END	

END
GO
